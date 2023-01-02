<template>
  <div class="dialog">
    <div class="center">
      <p>You have been challenged by user {{ challenger }} to a game!</p>
      <button @click="acceptChallenge()" class="button-6">Accept</button>
      <button @click="declineChallenge()" class="button-6" style="float: right">Decline</button>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue';
import {closeDialog} from 'vue3-promise-dialog'
import CustomIcon from "../icons/CustomIcon.vue";

export default defineComponent({
  props: {
    challenger: String
  },
  methods: {
    acceptChallenge(){
      closeDialog({'type': 'challenge', 'recipient': this.challenger, 'state': 'accept', 'action': 'manual'})
    },
    declineChallenge(){
      closeDialog({'type': 'challenge', 'recipient': this.challenger, 'state': 'decline', 'action': 'manual'})
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

.button-6 {
  margin: 10px 10px 0 0;
}
</style>
