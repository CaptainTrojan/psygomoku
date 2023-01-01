<template>
  <canvas @click="canvasClicked" width="600" height="600" ref="canvas"></canvas>
</template>

<script>
import {current_user} from "@/store";
import CryptoJS from 'crypto-js';

const STATE = {
  MARKING: 0,
  GUESSING: 1,
  WAITING: 2,
  WON: 3,
  LOST: 4,
  DREW: 5
}

const COLOR = {
  WHITE: 0,
  BLACK: 1
}

const POSSIBLE_NEIGHBORS = [
  [1, 0],
  [1, 1],
  [0, 1],
  [-1, 1],
];

function dec2hex(dec) {
  return dec.toString(16).padStart(2, "0")
}

function generateId() {
  let arr = new Uint8Array(64);
  window.crypto.getRandomValues(arr)
  return Array.from(arr, dec2hex).join('')
}

export default {
  name: "PsyGomoku",

  data() {
    const NUM_BLOCKS = 15;
    const BLOCK_SIZE = 40;
    const SIZE_IN_PIXELS = NUM_BLOCKS * BLOCK_SIZE;

    return {
      CryptoJS,
      current_user,
      turn: COLOR.WHITE,
      state: STATE.WAITING,
      whitePieces: new Set(),
      blackPieces: new Set(),
      SIZE_IN_PIXELS: SIZE_IN_PIXELS,
      NUM_BLOCKS,
      BLOCK_SIZE,
      SQUARE_MARGIN: 5,
      GRID_THICKNESS: 1, // doesn't actually work, but ey, whatchu gonna do
      SYMBOL_THICKNESS: 5,
      COLOR_BACKGROUND: '#ffffff',
      COLOR_GRID: '#cecece',
      COLOR_WHITE: '#d38848',
      COLOR_BLACK: '#6464fa',
      COLOR_QUESTION: '#d2ca92',
      COLOR_MARKED: '#e35050',
      FONT_SYMBOL: "bold 23px monospace",
      question_showing: false,
      key: undefined,
      mark: {'row': 0, 'column': 0},
      mark_showing: false,
      encryptedMark: undefined
    }
  },
  methods: {
    isMyTurn() {
      // noinspection EqualityComparisonWithCoercionJS,JSIncompatibleTypesComparison
      return !this.current_user.is_white == this.turn;
    },
    moveObjectToId(move){
      return move.row * this.NUM_BLOCKS + move.column;
    },
    handleMessage(message) {
      console.log("Captured message", message);

      if (this.state !== STATE.WAITING || !message.hasOwnProperty('phase') || !message.hasOwnProperty('value')) {
        console.log("Received corrupted message or at invalid time:", message);
        return;
      }

      if (this.isMyTurn()) {
        // expecting plaintext guess

        if (message.phase !== 'guess' || !this.verifyMove(message.value)) {
          console.log("Received corrupted message", message);
          return;
        }

        this.$emit('send-message', {
          'type': 'move',
          'phase': 'verify',
          'value': this.key,
          'recipient': current_user.other_nickname
        })

        this.performMove(this.mark, message.value);
      } else {
        // expecting encrypted mark or verification

        if (message.phase === 'mark') {
          if (typeof message.value !== "string") {
            console.log("Received corrupted message", message);
            return;
          }

          this.encryptedMark = message.value;
          this.state = STATE.GUESSING;
          this.updateStatus();
        } else if (message.phase === 'verify') {
          if (typeof message.value !== "string") {
            console.log("Received corrupted message", message);
            return;
          }
          let decrypted_mark;
          try {
            decrypted_mark = this.CryptoJS.AES.decrypt(this.encryptedMark, message.value).toString(this.CryptoJS.enc.Utf8);
            decrypted_mark = JSON.parse(decrypted_mark);
          } catch {
            console.log("Received corrupted message", message);
            return;
          }

          if (!this.verifyMove(decrypted_mark)) {
            console.log("Received corrupted message", message);
            return;
          }

          this.performMove(decrypted_mark, this.mark);
        } else {
          console.log("Received corrupted message", message);
        }
      }
    },
    canvasClicked(event) {
      if (this.state >= STATE.WAITING) {
        return;
      }

      let row = Math.floor(event.offsetX / this.BLOCK_SIZE);
      let column = Math.floor(event.offsetY / this.BLOCK_SIZE);
      let move = {row: row, column: column};

      if(this.whitePieces.has(this.moveObjectToId(move))) return;
      if(this.blackPieces.has(this.moveObjectToId(move))) return;
      if (move.row >= this.NUM_BLOCKS || move.row < 0 || move.column >= this.NUM_BLOCKS || move.column < 0) return;

      if (!this.question_showing || this.mark.row !== move.row || this.mark.column !== move.column) {
        this.mark = move;
        this.question_showing = true;
      } else {
        this.question_showing = false;
        this.mark_showing = true;

        if (this.state === STATE.MARKING) {
          this.key = generateId();
          let ciphertext = this.CryptoJS.AES.encrypt(
              JSON.stringify({'row': this.mark.row, 'column': this.mark.column}),
              this.key
          ).toString();

          this.$emit('send-message', {
            'type': 'move',
            'phase': 'mark',
            'value': ciphertext,
            'recipient': current_user.other_nickname
          })
          // waiting for guess
          console.log("Waiting for guess...");
        }else{ // GUESSING
          this.$emit('send-message', {
            'type': 'move',
            'phase': 'guess',
            'value': this.mark,
            'recipient': current_user.other_nickname
          })
          // waiting for verify
          console.log("Waiting for verify...");
        }
        this.state = STATE.WAITING;
        this.updateStatus();
      }
      this.renderAll();
    },
    performMove(label, output) {
      console.log("Performing move... ", label, output, this.turn, this.current_user.is_white);
      let to_check;
      let last_player = this.turn;
      if (output.row === label.row && output.column === label.column) { // guessed right
        to_check = this.turn === COLOR.WHITE ? this.blackPieces : this.whitePieces;
      } else { // guessed wrong
        to_check = this.turn === COLOR.WHITE ? this.whitePieces : this.blackPieces;
        this.turn = 1 - this.turn;
      }
      to_check.add(this.moveObjectToId(label));

      this.encryptedMark = undefined;
      this.mark_showing = false;
      this.question_showing = false;
      this.key = undefined;

      // set proper status for self
      let win = this.checkWin(to_check, label);
      this.renderAll();

      if(win.exists){
        this.drawVictoryStroke(win.stroke);
        // noinspection EqualityComparisonWithCoercionJS,JSIncompatibleTypesComparison
        this.state = !this.current_user.is_white == last_player ? STATE.LOST : STATE.WON;
        this.updateStatus();
      }else if(this.checkDraw()){
        this.state = STATE.DREW;
        this.updateStatus();
      }else{
        if (this.isMyTurn()) {
          this.state = STATE.MARKING;
          this.updateStatus();
        } else {
          this.state = STATE.WAITING;
          this.updateStatus();
        }
      }
    },
    checkDraw() {
      return this.whitePieces.size + this.blackPieces.size === this.NUM_BLOCKS * this.NUM_BLOCKS;
    },
    checkWin(set_of_moves, last_move) {
      for(let shift of POSSIBLE_NEIGHBORS){
        let win = this.checkWinForShift(set_of_moves, last_move, shift)
        if(win.exists){
          return win;
        }
      }
      return {'exists': false}
    },
    checkWinForShift(set_of_moves, last_move, shift) {
      let hits = 0;
      let A = Object.assign({}, last_move), B = Object.assign({}, last_move);

      //positive direction
      for(let i = 1; i < 5; i++){
        let move = Object.assign({}, last_move);
        move.row += i * shift[0];
        move.column += i * shift[1];
        if(this.fitsBound(move) && set_of_moves.has(this.moveObjectToId(move))){
          hits++;
          A = move;
        }else{
          break;
        }
      }

      // negative direction
      for(let i = -1; i > -5; i--){
        let move = Object.assign({}, last_move);
        move.row += i * shift[0];
        move.column += i * shift[1];
        if(this.fitsBound(move) && set_of_moves.has(this.moveObjectToId(move))){
          hits++;
          B = move;
        }else{
          break;
        }
      }

      if(hits >= 4){
        return {exists: true, stroke: {from: A, to: B}}
      }else{
        return {exists: false}
      }
    },
    fitsBound(value) {
      return value.row >= 0
          && value.column >= 0
          && value.row < this.NUM_BLOCKS
          && value.column < this.NUM_BLOCKS;
    },
    verifyMove(value) {
      let almost_valid = typeof value === "object"
          && value.hasOwnProperty('row')
          && value.hasOwnProperty('column')
          && typeof value.row === "number"
          && typeof value.column === "number"
          && this.fitsBound(value);
      if (!almost_valid) return false;

      let move_object_id = this.moveObjectToId(value);
      if (this.whitePieces.has(move_object_id)) return false;
      if (this.blackPieces.has(move_object_id)) return false;

      return true;
    },
    restart() {
      this.whitePieces.clear();
      this.blackPieces.clear();
      this.current_user.is_white = !this.current_user.is_white;
      this.turn = COLOR.WHITE;
      this.state = this.current_user.is_white ? STATE.MARKING : STATE.WAITING;
      this.updateStatus();

      // this.whitePieces.push([1, 1], [2, 2]);
      // this.blackPieces.push([3, 1], [4, 2]);
    },
    updateStatus() {
      let status = "<unk>";
      switch (this.state){
        case STATE.WAITING: {
          status = this.current_user.other_nickname + " is thinking..."
          break;
        }
        case STATE.MARKING: {
          status = "Mark the square on which you'd like to draw your symbol."
          break;
        }
        case STATE.GUESSING: {
          status = "Try to guess the square marked by your enemy!"
          break;
        }
        case STATE.WON: {
          status = "You won, well played."
          break;
        }
        case STATE.LOST: {
          status = "You lost. Nice try :)"
          break;
        }
        case STATE.DREW: {
          status = "cringe"
          break;
        }
      }
      this.$emit('set-status', status);
    },
    renderAll() {
      this.ctx.clearRect(0, 0, this.SIZE_IN_PIXELS, this.SIZE_IN_PIXELS);

      this.drawGrid();
      this.whitePieces.forEach(id => this.drawWhitePieceFromId(id));
      this.blackPieces.forEach(id => this.drawBlackPieceFromId(id));
      if (this.question_showing) {
        this.drawQuestionMarkSquare(this.mark.row, this.mark.column);
      } else if (this.mark_showing) {
        this.drawMarkedSquare(this.mark.row, this.mark.column);
      }
    },
    drawGrid() {
      this.ctx.beginPath();
      this.ctx.lineWidth = this.GRID_THICKNESS;
      for (let i = 1; i < this.NUM_BLOCKS; i++) {
        let pos = i * this.BLOCK_SIZE - 1;
        this.ctx.moveTo(pos, 0);
        this.ctx.lineTo(pos, this.SIZE_IN_PIXELS);
        this.ctx.moveTo(0, pos);
        this.ctx.lineTo(this.SIZE_IN_PIXELS, pos);
      }
      this.ctx.strokeStyle = this.COLOR_GRID;
      this.ctx.stroke();
    },
    drawQuestionMarkSquare(row, column) {
      this.ctx.beginPath();
      this.ctx.lineWidth = this.SYMBOL_THICKNESS;
      this.ctx.rect(
          row * this.BLOCK_SIZE + this.SQUARE_MARGIN + this.GRID_THICKNESS * 0.5,
          column * this.BLOCK_SIZE + this.SQUARE_MARGIN + this.GRID_THICKNESS * 0.5,
          this.BLOCK_SIZE - this.SQUARE_MARGIN * 2 - this.GRID_THICKNESS * 3,
          this.BLOCK_SIZE - this.SQUARE_MARGIN * 2 - this.GRID_THICKNESS * 3,
      )
      this.ctx.strokeStyle = this.COLOR_QUESTION;
      this.ctx.stroke();
      this.ctx.fillStyle = this.COLOR_QUESTION;
      this.ctx.font = this.FONT_SYMBOL;
      this.ctx.fillText("?", (row + 0.32) * this.BLOCK_SIZE, (column + 0.7) * this.BLOCK_SIZE)
    },
    drawMarkedSquare(row, column) {
      this.ctx.beginPath();
      this.ctx.lineWidth = this.SYMBOL_THICKNESS;
      this.ctx.rect(
          row * this.BLOCK_SIZE + this.SQUARE_MARGIN + this.GRID_THICKNESS * 0.5,
          column * this.BLOCK_SIZE + this.SQUARE_MARGIN + this.GRID_THICKNESS * 0.5,
          this.BLOCK_SIZE - this.SQUARE_MARGIN * 2 - this.GRID_THICKNESS * 3,
          this.BLOCK_SIZE - this.SQUARE_MARGIN * 2 - this.GRID_THICKNESS * 3,
      )
      this.ctx.strokeStyle = this.COLOR_MARKED;
      this.ctx.stroke();
      this.ctx.fillStyle = this.COLOR_MARKED;
      this.ctx.font = this.FONT_SYMBOL;
      this.ctx.fillText("!", (row + 0.32) * this.BLOCK_SIZE, (column + 0.7) * this.BLOCK_SIZE)
    },
    drawClearSquare(row, column) {
      this.ctx.beginPath();
      this.ctx.rect(
          row * this.BLOCK_SIZE + this.SQUARE_MARGIN,
          column * this.BLOCK_SIZE + this.SQUARE_MARGIN,
          this.BLOCK_SIZE - this.SQUARE_MARGIN * 2,
          this.BLOCK_SIZE - this.SQUARE_MARGIN * 2,
      )
      this.ctx.fillStyle = this.COLOR_BACKGROUND;
      this.ctx.fill();
    },
    drawWhitePieceFromId(id) {
      let column = id % this.NUM_BLOCKS;
      let row = Math.floor(id / this.NUM_BLOCKS);
      this.ctx.beginPath();
      this.ctx.lineWidth = this.SYMBOL_THICKNESS;
      this.ctx.ellipse(
          (row + 0.5) * this.BLOCK_SIZE - this.GRID_THICKNESS * 0.5,
          (column + 0.5) * this.BLOCK_SIZE - this.GRID_THICKNESS * 0.5,
          this.BLOCK_SIZE * 0.5 - this.SQUARE_MARGIN - this.GRID_THICKNESS,
          this.BLOCK_SIZE * 0.5 - this.SQUARE_MARGIN - this.GRID_THICKNESS,
          0,
          0,
          2 * Math.PI,
      )
      this.ctx.strokeStyle = this.COLOR_WHITE;
      this.ctx.fillStyle = this.COLOR_BACKGROUND;
      this.ctx.stroke();
    },
    drawBlackPieceFromId(id) {
      let column = id % this.NUM_BLOCKS;
      let row = Math.floor(id / this.NUM_BLOCKS);
      this.ctx.beginPath();
      this.ctx.lineWidth = this.SYMBOL_THICKNESS;
      this.ctx.moveTo(row * this.BLOCK_SIZE + this.SQUARE_MARGIN + this.GRID_THICKNESS * 0.5, column * this.BLOCK_SIZE + this.SQUARE_MARGIN + this.GRID_THICKNESS * 0.5);
      this.ctx.lineTo((row + 1) * this.BLOCK_SIZE - this.SQUARE_MARGIN - this.GRID_THICKNESS * 2, (column + 1) * this.BLOCK_SIZE - this.SQUARE_MARGIN - this.GRID_THICKNESS * 2);
      this.ctx.moveTo((row + 1) * this.BLOCK_SIZE - this.SQUARE_MARGIN - this.GRID_THICKNESS * 2, column * this.BLOCK_SIZE + this.SQUARE_MARGIN + this.GRID_THICKNESS * 0.5);
      this.ctx.lineTo((row) * this.BLOCK_SIZE + this.SQUARE_MARGIN + this.GRID_THICKNESS * 0.5, (column + 1) * this.BLOCK_SIZE - this.SQUARE_MARGIN - this.GRID_THICKNESS * 2);
      this.ctx.strokeStyle = this.COLOR_BLACK;
      this.ctx.fillStyle = this.COLOR_BACKGROUND;
      this.ctx.stroke();
    },
    drawVictoryStroke(stroke) {
      this.ctx.beginPath();
      this.ctx.lineWidth = this.SYMBOL_THICKNESS * 0.5 + 1;
      this.ctx.moveTo((stroke.from.row + 0.5) * this.BLOCK_SIZE, (stroke.from.column + 0.5) * this.BLOCK_SIZE);
      this.ctx.lineTo((stroke.to.row + 0.5) * this.BLOCK_SIZE, (stroke.to.column + 0.5) * this.BLOCK_SIZE);
      this.ctx.strokeStyle = this.COLOR_MARKED;
      this.ctx.stroke();
    },
  },
  mounted() {
    this.ctx = this.$refs.canvas.getContext('2d');
    // this.ctx.filter = "url(data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxmaWx0ZXIgaWQ9ImZpbHRlciIgeD0iMCIgeT0iMCIgd2lkdGg9IjEwMCUiIGhlaWdodD0iMTAwJSIgY29sb3ItaW50ZXJwb2xhdGlvbi1maWx0ZXJzPSJzUkdCIj48ZmVDb21wb25lbnRUcmFuc2Zlcj48ZmVGdW5jUiB0eXBlPSJpZGVudGl0eSIvPjxmZUZ1bmNHIHR5cGU9ImlkZW50aXR5Ii8+PGZlRnVuY0IgdHlwZT0iaWRlbnRpdHkiLz48ZmVGdW5jQSB0eXBlPSJkaXNjcmV0ZSIgdGFibGVWYWx1ZXM9IjAgMSIvPjwvZmVDb21wb25lbnRUcmFuc2Zlcj48L2ZpbHRlcj48L3N2Zz4=#filter)";
    this.restart();
    this.renderAll();
  }
}
</script>

<style scoped>

</style>