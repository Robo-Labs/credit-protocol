import brownie
from brownie import Contract, interface, accounts, project, chain
import pytest


def test_new_loan(accounts, usdc, factory, locker, token, borrower, backer, lender, loan_contract, loanInfo) : 
    factory.proposeLoan(loanInfo , {'from' : borrower})
    # TO DO - Back Loan 
    chain.mine(1)
    token.approve(locker, 10000, {'from' : backer})
    locker.lockTokens(10000, 604800*2, {'from' : backer})
    factory.backLoan(10000, 0, {'from' : backer})
    # TO DO - Create Loan 
    factory.createLoan(0, {'from' : borrower})
    # TO DO - Lend from users 
    loan = loan_contract.at(factory.loanAddress(0))
    # TO DO - Borrow & Repay 

    token.approve(loan, 10000, {'from' : lender})
    loan.deposit(10000, {'from' : lender})

    loan.withdrawLentFunds({'from' : borrower})