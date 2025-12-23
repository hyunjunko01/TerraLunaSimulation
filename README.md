# Terra/Luna Simulation Project

A simplified simulation of the Terra/Luna system, designed to test the growth and collapse scenarios of an algorithmic stablecoin.

It implements the core minting, burning, and swap mechanics for UST (Terra) and LUNA, with price changes mainly driven by supply fluctuations.

## Purpose

- to find out why they collapsed
- to explore the potential improvements in algorithmic stablecoins

## Project Structure (Incomplete)

src/
 ├─ Protocols/
 │   ├─ AnchorProtocol/
 │   │   ├─ LUNAStakingSystem.sol   # LUNA staking engine
 │   │   ├─ USTDepositSystem.sol    # UST deposit engine
 │   │   └─ USTLoanSystem.sol       # UST loan engine
 │   └─ SwapProtocol/
 │       └─ TerraLunaEngine.sol     # Swap & price engine
 │
 └─ Tokens/
     ├─ Terra.sol        # UST stablecoin
     ├─ Luna.sol         # LUNA reserve token
     ├─ AnchorUST.sol    # Deposit receipt token (aUST)
     └─ BondedLUNA.sol   # Staked LUNA (bLUNA)



### TerraLunaEngine.sol

    - implement UST and LUNA basic swap logic
    - Users can always swap 1 UST to 1$ LUNA or vice versa.

### AnchorProtocol.sol

    - implement UST deposit system and LUNA staking logic
    - If users deposit UST, they will receive aUST in the form of UST recipt tokens.
    - If users stake LUNA , they will receive bLUNA

## Future

- implement multiple scenarios (growth scenario, collapse scenario)
- conduct experiments to explore possible improvements


