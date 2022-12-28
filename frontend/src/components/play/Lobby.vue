<template>
  <div id="header">
    <h3>Your name is {{current_user.nickname}}. State: {{state}}</h3>
  </div>
  <div id="player_list">
    <PlayerItem v-for="player in Object.values(players)"
                @challenging="challenging"
                :nickname="player.nickname"
                :state="player.state"
                :id="player.nickname"></PlayerItem>
  </div>
</template>

<script>
import PlayerItem from '@/components/play/PlayerItem.vue'
import {SocketioService, LobbyCallback} from "@/services/socketio.service";
import {closeDialog, openDialog} from "vue3-promise-dialog";
import ChallengingDialog from "@/components/play/ChallengingDialog.vue";
import ChallengedDialog from "@/components/play/ChallengedDialog.vue";
import {current_user} from "@/store";

const STATE = {
  IDLE: 'idle', CHALLENGING: 'challenging someone', CHALLENGED: 'being challenged', IN_GAME: 'in game'
}

export default {
  name: "Lobby",
  components: {PlayerItem},
  data() {
    let self = this;
    const CALLBACK = new LobbyCallback(
        async function (msg){
          console.log("<" + current_user.nickname + "> MESSAGE INCOMING: ", msg);

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
                  if(res.result === 'disconnected') {
                    self.popup(`The challenger, ${msg.sender}, has disconnected.`);
                  }else{
                    self.popup(`The challenger, ${msg.sender}, has cancelled the challenge.`);
                  }
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
              if(self.state === STATE.CHALLENGING && current_user.other_nickname === msg.sender){
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
              if(self.state === STATE.CHALLENGING && current_user.other_nickname === msg.sender){
                closeDialog({'result': 'declined'})
                self.popup(`${msg.sender} has declined your challenge request.`);
                self.stateIdle();
              }else{
                // doesn't have to send anything, because decline leaves user in lobby
              }
              break;
            }
            case 'close': {
              if(current_user.other_nickname === msg.sender &&
                  (self.state === STATE.CHALLENGED || self.state === STATE.CHALLENGING)){
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
          current_user.nickname = nickname;
          delete self.players[nickname];
        },
        function(users){
          console.log("Received users change", users);
          self.players = users;
          delete self.players[current_user.nickname];
        },
        function (user){
          console.log("Received user state update", user);
          if(self.players.hasOwnProperty(user.nickname)){
            self.players[user.nickname] = user;
          }
        },
        function(){
          console.log("Other disconnected.")
          closeDialog({'result': 'disconnected'})
          self.stateIdle();
        }
    );

    return {
      current_user,
      players: {},
      state: STATE.IDLE,
      popup_showing: false,
      CALLBACK
    }
  },
  emits: ['sendMessage', 'start-game', 'popup'],
  methods: {
    popup(text){
      this.$emit('popup', text);
    },
    stateIdle(){
      this.state = STATE.IDLE;
      current_user.other_nickname = null;
      SocketioService.setState(this.state, current_user.nickname);
    },
    stateChallenging(whom){
      this.state = STATE.CHALLENGING;
      current_user.other_nickname = whom;
      SocketioService.setState(this.state, current_user.nickname, current_user.other_nickname);
    },
    stateChallenged(by_whom){
      this.state = STATE.CHALLENGED;
      current_user.other_nickname = by_whom;
      SocketioService.setState(this.state, current_user.nickname, current_user.other_nickname);
    },
    stateInGame(with_whom){
      this.state = STATE.IN_GAME;
      current_user.other_nickname = with_whom;
      SocketioService.setState(this.state, current_user.nickname, current_user.other_nickname);
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
  mounted() {
    console.log("Mounting lobby...");
    SocketioService.registerHandlers(this.CALLBACK);

    this.stateIdle();
    SocketioService.getLobbyInfo();
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