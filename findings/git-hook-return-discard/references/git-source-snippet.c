		/* Good. */
		break;
	case REF_TRANSACTION_PREPARED:
		BUG("prepare called twice on reference transaction");
		break;
	case REF_TRANSACTION_CLOSED:
		BUG("prepare called on a closed reference transaction");
		break;
	default:
		BUG("unexpected reference transaction state");
		break;
	}

	if (refs->repo->disable_ref_updates) {
		strbuf_addstr(err,
			      _("ref updates forbidden inside quarantine environment"));
		return -1;
	}

	string_list_sort(&transaction->refnames);
	if (ref_update_reject_duplicates(&transaction->refnames, err))
		return REF_TRANSACTION_ERROR_GENERIC;

	/* Preparing checks before locking references */
	ret = run_transaction_hook(transaction, "preparing");
	if (ret) {
		ref_transaction_abort(transaction, err);
		die(_(abort_by_ref_transaction_hook), "preparing");
	}

	ret = refs->be->transaction_prepare(refs, transaction, err);
	if (ret)
		return ret;

	ret = run_transaction_hook(transaction, "prepared");
	if (ret) {
		ref_transaction_abort(transaction, err);
		die(_(abort_by_ref_transaction_hook), "prepared");
	}

	return 0;
}

int ref_transaction_abort(struct ref_transaction *transaction,
			  struct strbuf *err)
{
	struct ref_store *refs = transaction->ref_store;
	int ret = 0;

	switch (transaction->state) {
	case REF_TRANSACTION_OPEN:
		/* No need to abort explicitly. */
		break;
	case REF_TRANSACTION_PREPARED:
		ret = refs->be->transaction_abort(refs, transaction, err);
		break;
	case REF_TRANSACTION_CLOSED:
		BUG("abort called on a closed reference transaction");
		break;
	default:
		BUG("unexpected reference transaction state");
		break;
	}

	run_transaction_hook(transaction, "aborted");

	ref_transaction_free(transaction);
	return ret;
}

int ref_transaction_commit(struct ref_transaction *transaction,
			   struct strbuf *err)
{
	struct ref_store *refs = transaction->ref_store;
	int ret;

	switch (transaction->state) {
	case REF_TRANSACTION_OPEN:
		/* Need to prepare first. */
		ret = ref_transaction_prepare(transaction, err);
		if (ret)
			return ret;
		break;
	case REF_TRANSACTION_PREPARED:
		/* Fall through to finish. */
		break;
	case REF_TRANSACTION_CLOSED:
		BUG("commit called on a closed reference transaction");
		break;
	default:
		BUG("unexpected reference transaction state");
		break;
	}

	ret = refs->be->transaction_finish(refs, transaction, err);
	if (!ret && !(transaction->flags & REF_TRANSACTION_FLAG_INITIAL))
		run_transaction_hook(transaction, "committed");
	return ret;
}

enum ref_transaction_error refs_verify_refnames_available(struct ref_store *refs,
					  const struct string_list *refnames,
					  const struct string_list *extras,
					  const struct string_list *skip,
					  struct ref_transaction *transaction,
					  unsigned int initial_transaction,
					  struct strbuf *err)
{
	struct strbuf dirname = STRBUF_INIT;
	struct strbuf referent = STRBUF_INIT;
	struct string_list_item *item;
	struct ref_iterator *iter = NULL;
	struct strset conflicting_dirnames;
	struct strset dirnames;
	int ret = REF_TRANSACTION_ERROR_NAME_CONFLICT;

