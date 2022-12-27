<template>
  <div id="header">
    <h3>Your name is {{nickname}}. State: {{state}}</h3>
  </div>
  <div id="player_list">
    <PlayerItem v-for="player in Object.values(players)"
                @challenging="challenging"
                :nickname="player.nickname"
                :state="player.state"
                :id="players.nickname"></PlayerItem>
  </div>
</template>

<script>
import PlayerItem from '@/components/play/PlayerItem.vue'
import {SocketioService, LobbyCallback} from "@/services/socketio.service";
import {closeDialog, openDialog} from "vue3-promise-dialog";
import ChallengingDialog from "@/components/play/ChallengingDialog.vue";
import ChallengedDialog from "@/components/play/ChallengedDialog.vue";

const STATE = {
  IDLE: 'idle', CHALLENGING: 'challenging someone', CHALLENGED: 'being challenged', IN_GAME: 'in game'
}

export default {
  name: "Lobby",
  components: {PlayerItem},
  data() {
    return {
      nickname: "<unknown>",
      other_nickname: null,
      players: {},
      state: STATE.IDLE
    }
  },
  methods: {
    stateIdle(){
      this.state = STATE.IDLE;
      this.other_nickname = null;
      SocketioService.setState(this.state, this.nickname);
    },
    stateChallenging(whom){
      this.state = STATE.CHALLENGING;
      this.other_nickname = whom;
      SocketioService.setState(this.state, this.nickname, this.other_nickname);
    },
    stateChallenged(by_whom){
      this.state = STATE.CHALLENGED;
      this.other_nickname = by_whom;
      SocketioService.setState(this.state, this.nickname, this.other_nickname);
    },
    stateInGame(with_whom){
      this.state = STATE.IN_GAME;
      this.other_nickname = with_whom;
      SocketioService.setState(this.state, this.nickname, this.other_nickname);
      this.$emit('start-game');
    },

    async challenging(nickname){
      let message = {'type': 'challenge', 'recipient': nickname, 'state': 'open', 'action': 'manual'}
      SocketioService.sendMessage(message);

      this.stateChallenging(nickname);
      let res = await openDialog(ChallengingDialog, {challenged: nickname});
      if(res.hasOwnProperty('result')){
        console.log(res);
        if(res.result === 'accepted'){
          this.stateInGame(nickname);
          return;
        }
      } else {
        SocketioService.sendMessage(res);
      }
      this.stateIdle();
    },
  },
  emits: ['sendMessage', 'start-game'],
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
              if(self.state === STATE.IDLE){
                self.stateChallenged(msg.sender);
                let res = await openDialog(ChallengedDialog, {challenger: msg.sender});
                if(res.hasOwnProperty('result')){
                  console.log(res);  //todo RESULT: handle close
                }else{
                  SocketioService.sendMessage(res);
                  if(res.state === 'accept'){
                    self.stateInGame(msg.sender);
                    return;
                  }
                }
                self.stateIdle();
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
                self.stateIdle();
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
                self.stateIdle();
              }else{
                // doesn't have to send anything, because decline leaves user in lobby
              }
              break;
            }
            case 'close': {
              if(self.state === STATE.CHALLENGED && self.other_nickname === msg.sender){
                closeDialog({'result': 'closed'})
                self.stateIdle();
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
          delete self.players[nickname];
        },
        function(users){
          console.log("Received users change", users);
          self.players = users;
          delete self.players[self.nickname];
        },
        function (user){
          console.log("Received user state update", user);
          if(self.players.hasOwnProperty(user.nickname)){
            self.players[user.nickname] = user;
          }
        }
      )
    );

    this.stateIdle();
    SocketioService.getLobbyInfo();
  },
  unmounted() {
    SocketioService.unregisterLobbyHandlers();
    console.log("Unmounted lobby.");
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