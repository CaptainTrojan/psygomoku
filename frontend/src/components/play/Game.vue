<template>
  <h1>This is the game. You're {{ current_user.nickname }} and facing {{ current_user.other_nickname }}</h1>
  <button @click="$emit('end-game')">Quit</button>
</template>

<script>
import {SocketioService} from "@/services/socketio.service";
import {current_user} from "@/store";

export default {
  name: "Game",
  data(){
    return {
      current_user
    }
  },
  emits: ['end-game'],
}
</script>

<style scoped>

</style>