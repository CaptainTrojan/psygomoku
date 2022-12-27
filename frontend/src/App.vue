<template>
  <router-view></router-view>
  <DialogWrapper :transition-attrs="{name: 'dialog'}"/>
</template>

<script>

import {DialogWrapper} from "vue3-promise-dialog";

export default {
  name: "App",
  components: {DialogWrapper},
}
</script>

<style scoped>

</style>