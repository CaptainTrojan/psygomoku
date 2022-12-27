<template>
  <div class="dialog">
    <div class="center">
      <p>You have been challenged by user {{ challenger }} to a game!</p>
      <button @click="acceptChallenge()" class="btn">Accept</button>
      <button @click="declineChallenge()" class="btn">Decline</button>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue';
import {closeDialog} from 'vue3-promise-dialog'

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

.btn {
  margin: 10px;
}
</style>
