<template>
  <div id="full_view">
    <GameStatus ref="game_status" @end-game="quitGame" @should-restart="handleRematch" @send-message="sendMessage"/>
    <PsyGomoku ref="psygomoku_game" @allow-rematch="allowRematch" @set-status="setStatus" @send-message="sendMessage"/>
  </div>
</template>

<script>
import {GameCallback, SocketioService} from "@/services/socketio.service";
import {current_user} from "@/store";
import PsyGomoku from "@/components/play/PsyGomoku.vue";
import GameStatus from "@/components/play/GameStatus.vue";

export default {
  name: "Game",
  computed: {
    current_user() {
      return current_user
    }
  },
  components: {GameStatus, PsyGomoku},
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

            self.$refs.game_status.handleIncomingRematch(msg);

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
    }
  },
  emits: ['end-game', 'popup'],
  methods: {
    quitGame(){
      SocketioService.sendMessage({'type': 'game_state', 'value': 'quit', 'recipient': current_user.other_nickname})
      this.$emit('end-game');
    },
    handleRematch() {
      this.$refs.psygomoku_game.restart();
    },
    sendMessage(message){
      SocketioService.sendMessage(message);
    },
    setStatus(message){
      this.$refs.game_status.setStatus(message);
    },
    allowRematch(){
      this.$refs.game_status.allowRematch();
    }
  },
  mounted() {
    console.log("Mounting game...");
    SocketioService.registerHandlers(this.CALLBACK);
  }
}
</script>

<style scoped>
#full_view {
  display: flex;
  flex-direction: row;
  align-items: center; 
  min-width: 620px;
}

#game_wrapper {
  display: inline-block;
  margin-left: 30px;
}

@media (max-width: 1024px) {
  #full_view {
    flex-direction: column;
  }
  #game_wrapper {
    position: relative;
    top: 270px;
    width: 600px;
    margin-left: 0;
    /* margin-right: 25px; */
  }
}
</style>