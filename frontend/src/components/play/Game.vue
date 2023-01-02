<template>
  <button @click="quitGame" class="button-6" role="button">Quit</button>
  <button :disabled="rematch_disabled" @click="offerRematch" class="button-6" role="button">Rematch
    <img v-if="user_wants_rematch || enemy_wants_rematch" id="loading" src="/loading.gif" alt="this slowpoke moves" width="20" />
  </button>
  <div>
    <span :class="{game_white: current_user.is_white, game_black: ! current_user.is_white, name: true}">You: {{ current_user.nickname }}</span>
    <span :class="{game_white: ! current_user.is_white, game_black: current_user.is_white, name: true}" style="float: right;">Enemy: {{ current_user.other_nickname }}</span>
  </div>
  <PsyGomoku @allow-rematch="allowRematch" @set-status="setStatus" @send-message="sendMessage" ref="psygomoku_game"/>
  <div>
    <span id="status_bar" ref="status_bar">Game loaded.</span>
  </div>

</template>

<script>
import {GameCallback, SocketioService} from "@/services/socketio.service";
import {current_user} from "@/store";
import PsyGomoku from "@/components/play/PsyGomoku.vue";

export default {
  name: "Game",
  computed: {
    current_user() {
      return current_user
    }
  },
  components: {PsyGomoku},
  data(){
    let self = this;

    const CALLBACK = new GameCallback(
      async function (msg){
        console.log("<" + current_user.nickname + "> MESSAGE INCOMING: ", msg);

        if(!msg.hasOwnProperty('type')
            || !msg.hasOwnProperty('sender')
            || !msg.hasOwnProperty('recipient')){
          console.log("Received corrupted message", msg);
          return;
        }

        switch (msg.type){
          case 'game_state': {
            if(!msg.hasOwnProperty('value')){
              console.log("Received corrupted message", msg);
              return;
            }

            switch (msg.value){
              case 'quit': {
                self.$emit('end-game', current_user.other_nickname + " has quit the game.");
                return;
              }
            }
            break;
          }
          case 'rematch': {
            if(!msg.hasOwnProperty("value")){
              console.log("Received corrupted message", msg);
              return;
            }

            self.enemy_wants_rematch = msg.value;
            if(self.enemy_wants_rematch){
              if(self.user_wants_rematch){
                self.handleRematch();
              }else{
                self.setStatus(self.current_user.other_nickname + " has challenged you to a rematch!");
              }
            }else{
              self.setStatus(self.current_user.other_nickname + " has cancelled the rematch challenge.");
            }

            break;
          }
          default: {
            self.$refs.psygomoku_game.handleMessage(msg);
            break;
          }
        }
      },
      function (err){
        console.log("Received custom error", err);
      },
      function(){
        console.log("Other disconnected.")
        self.$emit('end-game', current_user.other_nickname + " has disconnected.");
      }
    );

    return {
      CALLBACK,
      user_wants_rematch: false,
      enemy_wants_rematch: false,
      rematch_disabled: true
    }
  },
  emits: ['end-game', 'popup'],
  methods: {
    quitGame(){
      SocketioService.sendMessage({'type': 'game_state', 'value': 'quit', 'recipient': current_user.other_nickname})
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
      this.$refs.psygomoku_game.restart();
      this.rematch_disabled = true;
    },
    sendMessage(message){
      SocketioService.sendMessage(message);
    },
    setStatus(message){
      this.$refs.status_bar.innerText = message;
    },
    allowRematch(){
      this.rematch_disabled = false;
    }
  },
  mounted() {
    console.log("Mounting game...");
    SocketioService.registerHandlers(this.CALLBACK);
  }
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
  font-size: 21px;
}

/* CSS */
</style>