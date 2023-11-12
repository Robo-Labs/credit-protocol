import brownie
from brownie import Contract, interface, accounts
import pytest


def test_new_loan(accounts, usdc, factory, borrower) : 
    loanInfo = {}
    factory.proposeLoan(loanInfo , {'from' : borrower})

    # TO DO - Back Loan 

    # TO DO - Create Loan 

    # TO DO - Lend from users 

    # TO DO - Borrow & Repay 