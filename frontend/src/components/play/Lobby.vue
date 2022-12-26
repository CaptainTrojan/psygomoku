<template>
  <div id="header">
    <h3>Your name is {{nickname}}.</h3>
  </div>
  <div id="player_list">
    <PlayerItem v-for="(item, index) in players"
                :nickname="item.nickname"
                :index="index"
                :id="item.nickname"></PlayerItem>
  </div>
</template>

<script>
import PlayerItem from '@/components/play/PlayerItem.vue'
import {SocketioService, LobbyCallback} from "@/services/socketio.service";

const noop = () => {};
const EMPTY_CALLBACK = new LobbyCallback(noop, noop, noop, noop);

export default {
  name: "Lobby",
  components: {PlayerItem},
  data() {
    return {
      nickname: "<unknown>",
      players: []
    }
  },
  beforeMount() {
    console.log("Mounting lobby...");
    let self = this;
    SocketioService.registerLobbyHandlers(
      new LobbyCallback(
        function (msg){
          console.log("Received message", msg);
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