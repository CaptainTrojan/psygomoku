<template>
  <h1>This is the game.</h1>
  <button @click="$emit('end-game')">Quit</button>
</template>

<script>
import {SocketioService} from "@/services/socketio.service";
// TODO Pinia/VUEX?

export default {
  name: "Game",
  emits: ['end-game'],
}
</script>

<style scoped>

</style>