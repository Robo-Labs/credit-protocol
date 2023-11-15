import brownie
from brownie import Contract, interface, accounts, project, chain
import pytest


def test_default(accounts, usdc, factory, locker, token, borrower, backer, lender, loan_contract, loanInfo, amount) : 
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
    lenderBal = usdc.balanceOf(lender)
    borrowerBal = usdc.balanceOf(borrower)
    usdc.approve(loan, amount, {'from' : lender})
    loan.deposit(amount, {'from' : lender})
    assert usdc.balanceOf(lender) == lenderBal - amount
    assert usdc.balanceOf(loan) == amount
    loan.withdrawLentFunds({'from' : borrower})
    assert usdc.balanceOf(borrower) == borrowerBal + amount
    amtOwed = loan.calcTotalDue()
    assert amtOwed >= amount
    chain.sleep(loanInfo[5][-1])
    chain.mine(1)

    assert loan.hasDefaulted() 



    