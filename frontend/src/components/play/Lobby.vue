<template>
  <div id="header">
    <h3>Your name is {{nickname}}. State: {{state}}</h3>
  </div>
  <div id="player_list">
    <PlayerItem v-for="(item, index) in players"
                @challenging="challenging"
                :nickname="item.nickname"
                :index="index"
                :id="item.nickname"></PlayerItem>
  </div>
</template>

<script>
import PlayerItem from '@/components/play/PlayerItem.vue'
import {SocketioService, LobbyCallback} from "@/services/socketio.service";
import {closeDialog, openDialog} from "vue3-promise-dialog";
import ChallengingDialog from "@/components/play/ChallengingDialog.vue";
import ChallengedDialog from "@/components/play/ChallengedDialog.vue";

const noop = () => {};
const EMPTY_CALLBACK = new LobbyCallback(noop, noop, noop, noop);

const STATE = {
  DEFAULT: 'idle', CHALLENGING: 'challenging someone', CHALLENGED: 'being challenged'
}

export default {
  name: "Lobby",
  components: {PlayerItem},
  data() {
    return {
      nickname: "<unknown>",
      other_nickname: null,
      players: [],
      state: STATE.DEFAULT
    }
  },
  methods: {
    stateDefault(){
      this.state = STATE.DEFAULT;
      this.other_nickname = null;
    },
    stateChallenging(whom){
      this.state = STATE.CHALLENGING;
      this.other_nickname = whom;
    },
    stateChallenged(by_whom){
      this.state = STATE.CHALLENGED;
      this.other_nickname = by_whom;
    },

    async challenging(nickname){
      let message = {'type': 'challenge', 'recipient': nickname, 'state': 'open', 'action': 'manual'}
      SocketioService.sendMessage(message);

      this.stateChallenging(nickname);
      let res = await openDialog(ChallengingDialog, {challenged: nickname});
      if(res.hasOwnProperty('result')){
        console.log(res); //todo RESULT: handle cancel (easy)
      } else {
        SocketioService.sendMessage(res);
      }
      this.stateDefault();
    },
  },
  emits: ['sendMessage'],
  beforeMount() {
    console.log("Mounting lobby...");
    let self = this;
    SocketioService.registerLobbyHandlers(
      new LobbyCallback(
        async function (msg){
          console.log("<" + self.nickname + "> MESSAGE INCOMING: ", msg);

          if(!msg.hasOwnProperty('type')
              || !msg.hasOwnProperty('sender')
              || !msg.hasOwnProperty('recipient')){
            console.log("Received corrupted message", msg);
            return;
          }

          if(!msg.type === 'challenge'){
            console.log("Received message with unknown type ", msg);
            return;
          }

          if(!msg.hasOwnProperty('state')){
            console.log("Received corrupted message", msg);
            return;
          }

          switch(msg.state){
            case 'open': {
              if(self.state === STATE.DEFAULT){
                self.stateChallenged(msg.sender);
                let res = await openDialog(ChallengedDialog, {challenger: msg.sender});
                if(res.hasOwnProperty('result')){
                  console.log(res);  //todo RESULT: handle cancel
                }else{
                  SocketioService.sendMessage(res);
                }
                self.stateDefault();
              }else{
                // send decline, because open will lead to challenging dialog
                SocketioService.sendMessage(
                    {'type': 'challenge', 'sender': msg.recipient,
                      'recipient': msg.sender, 'state': 'decline', 'action': 'auto'});
              }
              break;
            }
            case 'accept': {
              if(self.state === STATE.CHALLENGING && self.other_nickname === msg.sender){
                closeDialog({'result': 'accepted'})
                alert("Accepted!");
                self.stateDefault();
              }else{
                // send close, because accept will lead to game screen
                SocketioService.sendMessage(
                    {'type': 'challenge', 'sender': msg.recipient,
                      'recipient': msg.sender, 'state': 'close', 'action': 'auto'});
              }
              break;
            }
            case 'decline': {
              if(self.state === STATE.CHALLENGING && self.other_nickname === msg.sender){
                closeDialog({'result': 'declined'})
                alert("Declined!");
                self.stateDefault();
              }else{
                // doesn't have to send anything, because decline leaves user in lobby
              }
              break;
            }
            case 'close': {
              if(self.state === STATE.CHALLENGED && self.other_nickname === msg.sender){
                closeDialog({'result': 'closed'})
                self.stateDefault();
              }else{
                // doesn't have to send anything, because close leaves user in lobby
              }
              break;
            }
          }
        },
        function (err){
          console.log("Received custom error", err);
        },
        function (nickname){
          console.log("Received nickname", nickname);
          self.nickname = nickname;
          self.players = self.players.filter(user => user.nickname !== self.nickname);
        },
        function(users){
          console.log("Received users change", users);
          self.players = users.filter(user => user.nickname !== self.nickname)
        }
      )
    );
  },
  unmounted() {
    console.log("Unmounted lobby.");
    SocketioService.registerLobbyHandlers(EMPTY_CALLBACK);
  }
}
</script>

<style scoped>
@media (min-width: 600px) {
  #header{
    width: 600px;
  }
}
#header {
  display: block;
  border-bottom: 2px solid #767676;
  margin-bottom: 40px;
}

#header>h3 {
  width: 100%;
}
</style>