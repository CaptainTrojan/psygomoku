<template>
  <div>
    <h2>Player: {{nickname}}</h2>
  </div>
</template>

<script>
export default {
  name: "PlayerItem",
  props: {
    nickname: { required: true, type: String}
  }
}
</script>

<style scoped>

</style>