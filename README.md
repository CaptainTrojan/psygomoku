[![Build and Deploy](https://github.com/CaptainTrojan/psygomoku/actions/workflows/deploy.yml/badge.svg)](https://github.com/CaptainTrojan/psygomoku/actions/workflows/deploy.yml)

The application is deployed at http://psygomoku.ddns.net 

# What is psygomoku?

Psygomoku has the same rules as the original [gomoku](https://en.wikipedia.org/wiki/Gomoku) game (tic-tac-toe on a 15x15 grid, 5-in-a-row wins). However, anytime you want to draw a symbol, you instead mark the square and your opponent gets a chance to guess that square. If they guess correctly, it is them that gets to draw their symbol on the marked square, not you, and you play again. If they don't guess correctly, you draw your symbol on the marked square and the turn switches.

# Server

The game was originally meant to be implemented for Android using Bluetooth or any other P2P technology. For this reason, the intermediary server only really performs two tasks:
- manage a list of connected clients (update, track state, broadcast to others), and
- pass Object messages between clients

# Client

A browser Vue.js client which does all the heavy lifting. Since all peers are equal, there are only 2 in a single game, and no authority exists, there is a possibility to write a custom (perhaps malicious) client. The original client is implemented in such a way that it ignores all illegal messages (for example moves outside the board, on a taken square, etc.) or messages sent at a wrong time (a challenge request for a player already in game). A single turn is also split into a three-way mark/guess/verify process implemented using a symmetric AES cipher, where
1. Alice <b>marks</b> the field, generates a key, encrypts the field and sends it to Bob
2. Bob stores the encrypted field somewhere
3. Bob <b>guesses</b> the field and sends it in plaintext to Alice
4. Alice now has both the marked and guessed field, she checks whether guessed is legal and proceeds according to the rules above.
5. Alice <b>sends her key</b> to Bob
6. Bob decrypts the encrypted field using the key
7. Bob now has both the marked and guessed field, he checks whether marked is legal and proceeds according to the rules above.
