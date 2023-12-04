# Kashidashi Finance 

![city](https://github.com/Robo-Labs/credit-protocol/assets/86513395/d0f786f2-1780-4a1a-a3c9-99fd692df10b)

In the evolving landscape of Decentralized Finance (DeFi), a striking contrast is evident when compared to traditional finance (TradFi) concerning lending practices. In DeFi, the majority of loans are overcollateralized, requiring borrowers to lock in assets exceeding the loan value. This approach, while reducing risk, significantly limits accessibility and excludes potential borrowers who lack adequate collateral. Conversely, in TradFi, undercollateralized lending is the norm, allowing more flexible and inclusive credit options.Kashidashi Finance addresses this disparity by introducing a platform that facilitates undercollateralized lending in the DeFi space. This shift not only aligns DeFi more closely with TradFi's inclusivity but also opens new avenues for credit extension and financial participation. A pivotal feature of our platform is the incorporation of a secondary market dedicated to the buying and selling of rights to future cash flows from loans. This market serves a dual purpose: it allows for more efficient risk pricing of loans and provides lenders with the opportunity to liquidate their positions early if desired. By enabling these transactions, our protocol introduces a level of liquidity and flexibility to undercollateralized lending, making it a novel solution in the realm of decentralized credit.

Through these innovations, our protocol aims to bridge the gap between DeFi and TradFi, offering a more inclusive, flexible, and efficient lending environment. By democratizing access to credit and enhancing liquidity options, we are poised to redefine the landscape of decentralized lending

# Protocol Overview

At the heart of our Kashidashi is a dynamic system designed to transform how loans are created, backed, and managed within the DeFi ecosystem. This section outlines the key mechanisms of loan creation, the role and incentives for backers, and the tokenization process that underpins the liquidity and flexibility of the system.

![overview](https://github.com/Robo-Labs/credit-protocol/assets/86513395/55bdb52a-a84b-497d-811b-c237666e3dde)

A) Creation of Loans

![rep](https://github.com/Robo-Labs/credit-protocol/assets/86513395/8b30506c-2c13-4a4c-9ef6-d2d9dc437f21)

Loans in our protocol are initiated by borrowers who propose their terms, including the loan amount, repayment schedule, interest rate, and late payment penalties. The novel aspect of our system is the backing of these loans. Unlike traditional DeFi models that rely on overcollateralization, our platform requires loans to be backed by locked tokens from our community of backers. These backers, essentially, endorse a loan by locking a portion of their tokens to guarantee it. This method not only secures the loan but also ensures that backers are judicious in their support, as their tokens are at stake. The loan is approved only if it receives the minimum required backing, creating a decentralized vetting system where backers collectively determine the viability and trustworthiness of each loan request. This process democratically shifts the decision-making power to the community, fostering a more inclusive and engaged lending environment.

B) Backers' Role and Incentives

![specialised](https://github.com/Robo-Labs/credit-protocol/assets/86513395/7ed277c7-4fc1-40d8-bdc0-01bcd794779f)

Backers play a critical role in our ecosystem. They are not just passive token holders but active participants who assess and support loan proposals. In the event of a loan default, backers' locked tokens are slashed, aligning their interests with the successful repayment of the loan. This 'skin in the game' approach incentivizes backers to conduct due diligence, thus building a reputation system based on their backing history and success rate. In addition to the inherent responsibility, backers are also incentivized through a revenue share model. A portion of the interest paid on loans they back is distributed to them, creating a direct financial incentive. This mechanism ensures that backers are rewarded for their risk and involvement in the loan approval process, making it a potentially lucrative aspect of their participation in the platform.

C) Tokenization of Loans

![secondaryMarket](https://github.com/Robo-Labs/credit-protocol/assets/86513395/d987d79b-3320-45bd-92bb-ee8ecd888b9e)

A key innovation of our protocol is the tokenization of loans. Once a loan is approved and funded, the rights to its future cash flows are tokenized, typically in the form of ERC721 tokens. This approach offers two significant advantages: firstly, it allows for the seamless buying and selling of these rights in a secondary market, providing liquidity and flexibility to lenders. Lenders can choose to hold onto their tokens to receive the future cash flows from the loan repayments, or they can opt to sell these tokens in the secondary market, enabling them to liquidate their positions early. Secondly, the tokenization of loans facilitates efficient risk pricing. As these tokens are traded in the market, their value reflects the perceived risk and potential return of the underlying loans, providing transparent and dynamic pricing. This market-driven approach to risk assessment further enhances the robustness and sophistication of our lending ecosystem.


# Long-term Vision and Mechanics

Our protocol is not just a lending platform; it's a foundation for a new financial ecosystem. The modular design of our protocol is pivotal in this vision, offering unparalleled flexibility and scalability. This section delves into how our platform's modular structure enables a diverse range of functionalities and growth opportunities, paving the way for an innovative financial landscape.

A) Modular Design for Backers
Our protocol's modular nature allows backers to create their own custom lending platforms on top of our core system. This flexibility enables backers to automate loan approvals using a mix of on-chain and off-chain data, tailoring their criteria based on specific expertise or market needs. For example, a backer could establish a platform specializing in loans for renewable energy projects, utilizing both blockchain data and external environmental impact reports.

This capability transforms our protocol into a platform for backers to operate bank-like entities or debt facilities with unique lending propositions. An exciting application of this could be a backer combining the protocol with traditional fiat on-ramps to offer Web2-style lending services, drawing capital from DeFi into broader markets.

B) Delegated Lending for Lenders
For lenders, our protocol offers the ability to delegate assets to specific backers. This feature mimics the functionality of a savings account in traditional finance but with the added benefits of blockchain transparency and potentially higher returns. Lenders can automatically allocate their funds to loans backed by reputable backers with a proven track record, effectively managing their risk and return profile.

The presence of a secondary market further enhances this aspect by providing high liquidity. Lenders can quickly and easily sell their positions if needed, offering a level of flexibility and security rarely seen in traditional savings accounts.

C) Securitization of Cash Flows
Upon reaching a critical mass of loan activity, our protocol plans to introduce the securitization of cash flows, akin to Mortgage-Backed Securities (MBS) in traditional finance. This development will allow the pooling of various loans into tradable securities, providing investors with new avenues for diversification and risk management. It represents a significant step towards integrating DeFi lending with mainstream financial instruments.

D) Optional Collateral for Borrowers
To further enhance the accessibility and flexibility for borrowers, our protocol allows the option of providing collateral, including tokenized real-world assets (RWAs). This feature opens the door for a wider range of borrowers, especially those who can leverage their physical assets in the digital lending space. The inclusion of RWAs in the collateral framework not only broadens the scope of our lending platform but also bridges the gap between traditional and decentralized finance.
