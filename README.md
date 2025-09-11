# Terra/Luna Simulation Project

A simplified simulation of the Terra/Luna system, designed to test the growth and collapse scenarios of an algorithmic stablecoin.

It implements the core minting, burning, and swap mechanics for UST (Terra) and LUNA, with price changes mainly driven by supply fluctuations.

## Purpose

- to find out why they collapsed
- to explore the potential improvements in algorithmic stablecoins

## Project Structure (Incomplete)

    src/
    ├─ Terra.sol           # ERC20 stablecoin implementation (UST)
    ├─ Luna.sol            # ERC20 reserve token implementation (LUNA)
    ├─ AnchorUST.sol       # Anchor UST deposit receipt token
    ├─ BondedLUNA.sol      # Bonded LUNA
    ├─ TerraLunaEngine.sol # Engine handling swaps and price updates
    ├─ AnchorProtocol.sol  # Implement Anchor Protocol


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


