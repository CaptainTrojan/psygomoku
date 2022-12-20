<template>
  <router-view></router-view>
</template>

<script>
import SocketioService from "@/services/socketio.service";

export default {
  name: "App",
  components: {},
  created() {
    SocketioService.setupSocketConnection();
  }
}
</script>

<style scoped>

</style>