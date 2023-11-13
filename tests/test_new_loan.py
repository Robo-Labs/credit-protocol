import brownie
from brownie import Contract, interface, accounts
import pytest


def test_new_loan(accounts, usdc, factory, borrower, backer, lender, project) : 
    loanInfo = {}
    factory.proposeLoan(loanInfo , {'from' : borrower})
    # TO DO - Back Loan 
    factory.backLoan(10000, 0, {'from' : backer})
    # TO DO - Create Loan 
    factory.createLoan(0, {'from' : borrower})
    # TO DO - Lend from users 
    loan = project.CreditProtocol.LendingPool.at(factory.loadAddress(0))
    # TO DO - Borrow & Repay 

    loan.deposit()