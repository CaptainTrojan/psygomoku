<template>
  <img class="tooltip" data-text="tooltip text" :src="source" :alt="source">
</template>

<script>
export default {
  name: "CustomIcon",
  props: {
    source: String
  }
}
</script>

<style scoped>

</style>
