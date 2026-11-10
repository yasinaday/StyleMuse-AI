"""Operator-only manual Replicate Billing statement enrollment; never inference.

Load the existing runtime environment securely, set STYLEMUSE_ENABLED=false and
explicit STYLEMUSE_DB_PATH / STYLEMUSE_STORAGE_DIR before running this command.
No HTTP enrollment route. Does not rotate or display API keys.
"""
import argparse
import os
from decimal import Decimal
from providers import RealProviders
from store import Store


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot-id', required=True)
    parser.add_argument('--amount', required=True)
    parser.add_argument('--evidence', required=True)
    args = parser.parse_args()
    if os.environ.get('STYLEMUSE_ENABLED', '').lower() != 'false':
        parser.error('Set STYLEMUSE_ENABLED=false for operator enrollment')
    amount = Decimal(args.amount)
    if not amount.is_finite() or amount < 0 or amount != amount.quantize(Decimal('.000001')):
        parser.error('Amount must be nonnegative USD with at most six decimals')
    db_path = os.environ.get('STYLEMUSE_DB_PATH')
    storage_dir = os.environ.get('STYLEMUSE_STORAGE_DIR')
    if not db_path or not storage_dir:
        parser.error('Explicit DB/storage paths required')
    # Disabled gate and explicit paths precede app's module-level Store import.
    from app import Settings
    provider = RealProviders.from_env()
    try:
        account = provider.replicate_account()
        store = Store(Settings(db_path=db_path, storage_dir=storage_dir))
        store.record_manual_credit(args.snapshot_id, account, amount, args.evidence)
        print(__import__('json').dumps(store.manual_credit(account), sort_keys=True))
    finally:
        provider.close()


if __name__ == '__main__':
    main()
