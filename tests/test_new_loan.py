import brownie
from brownie import Contract, interface, accounts, project, chain
import pytest


def test_new_loan(accounts, usdc, factory, locker, token, borrower, backer, lender, loan_contract, loanInfo, amount) : 
    factory.proposeLoan(loanInfo , {'from' : borrower})
    # TO DO - Back Loan 
    chain.mine(1)
    token.approve(locker, 10000, {'from' : backer})
    locker.lockTokens(10000, 604800*2, {'from' : backer})
    factory.backLoan(10000, 0, {'from' : backer})
    # Create Loan 
    factory.createLoan(0, {'from' : borrower})
    # Lend from users 
    loan = loan_contract.at(factory.loanAddress(0))
    # Borrow & Repay 
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
    chain.sleep(1000)
    chain.mine(10)


    usdc.approve(loan, amtOwed * 2, {'from' : borrower})
    nPayments = len(loanInfo[4])
    for i in range(nPayments):
        tx = loan.repayNext({'from' : borrower})
        assert (loan.principleRepaid() + loan.interestEarned() + loan.latePayments()) == borrowerBal + amount - usdc.balanceOf(borrower)

    assert loan.loanFinal()
    amtOwed = loan.calcTotalDue()
    assert amtOwed == 0
    loan.withdraw(0, {'from' : lender})
    assert usdc.balanceOf(lender) >= lenderBal
    assert False



    