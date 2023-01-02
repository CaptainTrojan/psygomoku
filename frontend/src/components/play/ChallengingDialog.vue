<template>
  <div class="dialog">
    <div class="center">
      <CustomIcon style="width: 30px" source="/loading.gif"/>
      <p>Challenging user <i>{{challenged}}</i>&nbsp; to a game.</p>
      <p>Waiting for response...</p>
      <button @click="cancelChallenge()" class="button-6">Cancel</button>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue';
import {closeDialog} from 'vue3-promise-dialog'
import CustomIcon from "../icons/CustomIcon.vue";

export default defineComponent({
  components: {CustomIcon},
  props: {
    challenged: String
  },
  methods: {
    cancelChallenge(){
      closeDialog({'type': 'challenge', 'recipient': this.challenged, 'state': 'close', 'action': 'manual'})
    }
  }
});
</script>

<style scoped>
.dialog {
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  right: 0;
  background-color: rgba(0, 0, 0, 0.3);
}

.center {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  background-color: white;
  padding: 20px;
}
</style>
