# Airplane Boarding Simulation

This project was done as part of a masters course in statistics. The task was to create an agent based model for simulating a real world scenario, with freedom to choose any scenario to model. The scenario chosen here is people boarding an airplane at the airport.

This project was done in 2018 but was never gittified or pushed to Github. The project was uploaded to Github in Oct 2022.

## Install

You will need NetLogo to run the simulation. All downloads and docs can be found [here](https://ccl.northwestern.edu/netlogo/). NetLogo comes with a GUI that allows one to load, edit and run a simulation.

## Details of the sim

https://user-images.githubusercontent.com/48631759/198902577-7d2c7e89-97f5-4e6f-9626-b834f9545884.mp4

### Screenshots

![Setup](/Screenshots/0_setup.png?raw=true "Setup")
![Start](/Screenshots/1_start.png?raw=true "Start")
![Mid](/Screenshots/2_mid.png?raw=true "Mid")
![End](/Screenshots/3_end.png?raw=true "End")

### Features

- variable seating strategy that the airline uses, basically the order of passengers in the line before they board
- passengers have bags that take time to stow away
- a passenger may have to get up to let a fellow passenger into her seat if he is blocking her entrance to her seat

### Adjustable knobs

- seating topoloy of the airplane
- percentage of seats occupied
- 1 or 2 entrances to airplane
- selection of 3 different seating strategies (back-to-front, window-to-aisle, random)
- percent of passengers with bags
- time variation for each passenger to stow their bags

### Results of the sim

The following amount of steps were required to board passengers onto an airplane with 2 entrances, 32 rows, 6 columns, and passengers who filled 95% of the airplane, 80% of which had carry-on bags that they had to stow away:
- Random strategy: ~8k steps
- Window-to-aisle strategy: ~6k steps

The 2nd strategy has a 25% time improvement over the first.




