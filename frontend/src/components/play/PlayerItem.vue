<template>
  <div class="player-item">
    <h4>{{nickname}} {{state}} <button @click="emitChallenge(nickname)">challenge</button></h4>
  </div>
</template>

<script>

export default {
  name: "PlayerItem",
  props: {
    nickname: { required: true, type: String},
    state: {required: true, type: Object},
    id: {required: true, type: String},
  },
  methods: {
    emitChallenge(nickname) {
      this.$emit('challenging', nickname)
    }
  },
  emits: ["challenging"]
}
</script>

<style>
.player-item {
  padding: 10px;
  border: 2px solid hsla(160, 100%, 37%, 1);
  border-radius: 3px;
  margin-bottom: 5px;
  width: 100%;
}
</style>

<style scoped>

</style>