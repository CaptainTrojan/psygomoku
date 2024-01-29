<template>
  <div id="game_status">
    <button @click="quitGame" class="button-6" role="button">Quit</button>
    <button :disabled="rematch_disabled" @click="offerRematch" class="button-6" role="button">Rematch
      <img v-if="user_wants_rematch || enemy_wants_rematch" id="loading" src="/loading.gif" alt="this slowpoke moves" width="20" />
    </button>
    <p id="status_bar" ref="status_bar">Game loaded.</p>
    <p :class="{game_white: current_user.is_white, game_black: ! current_user.is_white, name: true}">You: {{ current_user.nickname }}</p>
    <div id="turn_indicator_wrapper">
      <p id="turn_indicator" ref="turn_indicator" :class="[this.turn_class]">...</p>
    </div>
    <p :class="{game_white: ! current_user.is_white, game_black: current_user.is_white, name: true}" style="float: right;">Enemy: {{ current_user.other_nickname }}</p>
  </div>
</template>

<script>
import {current_user} from "@/store";

export default {
  name: "GameStatus",
  computed: {
    current_user() {
      return current_user
    }
  },
  data() {
    return {
      user_wants_rematch: false,
      enemy_wants_rematch: false,
      rematch_disabled: true,
      turn_class: 'none',
      notification: new Audio('/notification.mp3'),
    }
  },
  emits: ['end-game', 'should-restart', 'send-message'],
  methods: {
    quitGame(){
      this.$emit('end-game');
    },
    offerRematch(){
      if(this.enemy_wants_rematch){
        this.sendMessage({'type': 'rematch', 'value': true, 'recipient': current_user.other_nickname})
        this.handleRematch();
      }else{
        this.user_wants_rematch = ! this.user_wants_rematch;
        if(this.user_wants_rematch){
          this.setStatus("You have challenged " + this.current_user.other_nickname + " to a rematch!");
        }else{
          this.setStatus("You have cancelled the rematch challenge.");
        }
        this.sendMessage({'type': 'rematch', 'value': this.user_wants_rematch, 'recipient': current_user.other_nickname})
      }
    },
    handleRematch() {
      this.user_wants_rematch = false;
      this.enemy_wants_rematch = false;
      this.$emit('should-restart');
      this.rematch_disabled = true;
    },
    handleIncomingRematch(msg){
      this.enemy_wants_rematch = msg.value;
      if(this.enemy_wants_rematch){
        if(this.user_wants_rematch){
          this.handleRematch();
        }else{
          this.setStatus(this.current_user.other_nickname + " has challenged you to a rematch!");
        }
      }else{
        this.setStatus(this.current_user.other_nickname + " has cancelled the rematch challenge.");
      }
    },
    sendMessage(message){
      this.$emit('send-message', message);
    },
    setStatus(status_object){
      if(typeof status_object === 'object'){
        this.$refs.status_bar.innerText = status_object.status;

        let message;
        switch (status_object.turn){
          case 'you': message = 'Your turn.'; break;
          case 'enemy': message = 'Enemy turn.'; break;
          case 'none': message = 'Game end.'; break;
        }

        this.adjustTurnIndicator(message, status_object.turn);
      }else{
        this.$refs.status_bar.innerText = status_object;
      }
    },
    allowRematch(){
      this.rematch_disabled = false;
    },
    adjustTurnIndicator(message, cls){
      this.$refs.turn_indicator.innerText = message;
      if(cls === 'you' && this.turn_class !== 'you'){
        this.notification.play();
      }
      this.turn_class = 'turn_indicator_' + cls;
    },
  },
}
</script>

<style scoped>
#loading {
  margin: 0 0 0 20px;
  padding: 0;
}

.button-6 {
  margin: 0 10px 10px 0;
}

.name {
  font-size: 17px;
  display: block;
  margin: 0 auto;
  width: 100%;
}

#status_bar {
  display: block;
  width: 100%;
  font-size: 11px;
  border-bottom: 1px solid black;
  border-top: 1px solid black;
  padding: 10px 0;
  margin: 10px 0;
}

#turn_indicator_wrapper {
  display: block;
  height: 200px;
}

#turn_indicator {
  padding: 5px;
  border-radius: 20px;
  width: 100%;
  position: absolute;
  text-align: center;
}

.turn_indicator_you {
    top: 0;
    background-color: #b3f9b5;
}

.turn_indicator_none {
    top: 0;
    background-color: #d8d8d8;
}

.turn_indicator_enemy {
    bottom: 0;
    background-color: #d8d8d8;
}

#game_status {
  display: inline-block;
  align-self: center;
  width: 350px;
  background-color: #fafafaad;
  padding: 30px;
  z-index: 1;
}

@media (max-width: 1024px) {
  #game_status {
    max-width: 600px;
    width: 100%;
    padding: 10px;
    position: fixed;
    top: 0;
  }

  #turn_indicator_wrapper {
    height: 80px;
  }
}

@media (max-width: 640px) {
  #game_status {
    left: 0;
    max-width: none;
  }
}
</style>