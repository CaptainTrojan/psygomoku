<template>
  <header>
    <h3>{{nickname}}</h3>
  </header>
  <ul id="player_list">

  </ul>
</template>

<script>
import PlayerItem from '@/components/play/PlayerItem.vue'

export default {
  name: "Lobby",
  data() {
    return {
      players: []
    }
  },
  methods: {
    onClickSpan(){
      console.log("awd");
      this.$emit('clickeded', 'some value lol');
    }
  }
}
</script>

<style scoped>

</style>