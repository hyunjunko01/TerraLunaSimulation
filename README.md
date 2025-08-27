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
    ├─ TerraLunaEngine.sol # Engine handling swaps and price updates

## Future

- implement multiple scenarios (growth scenario, collapse scenario, Anchor Protocol)
- conduct experiments to explore possible improvements


