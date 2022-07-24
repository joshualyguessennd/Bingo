# BINGO
Bingo is a luck-based game in which players match a randomized board of numbers with random numbers drawn by a host. The first player to achieve a line of numbers on their board and claim Bingo wins


# OVERVIEW

Wanting to develop a more decentralized system of the bingo game that we find online. I tried to design a smart contract that allows you to participate in several bingo games, pay a fixed fee for each game, and use the VRF 1 version of chainlink for a semblance of randomness, of course a code made only over a few hours cannot be said to be finished, there are still sections to improve and optimize.


# TODO

- more effective storage of prints.
the grid containing 5 columns, it is possible to draw 5 numbers for the same column as below [1-59, 1-1, 1-75, 1-22, 1-4], using a simple mapping will override the last value, store the values ​​in an array and optimize for a more in-depth search,

- using foundry forge and testing on a network fork , fetch chainlink randomn could not be very effective because of the late response.