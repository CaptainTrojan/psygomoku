<template>
  <tr class="player-item">
    <td class="username-column"><CustomIcon class="table-icon" source="/src/assets/user.svg"/><span>{{nickname}}</span></td>
    <td class="state-column"><CustomIcon class="table-icon" :source="stateImg"/></td>
    <td class="challenge-column"><button class="button-6" @click="emitChallenge(nickname)">challenge</button></td>
  </tr>
</template>

<script>

import CustomIcon from "@/components/icons/CustomIcon.vue";

export default {
  name: "PlayerItem",
  components:{
    CustomIcon,
  },
  computed: {
   stateImg() {
      switch (this.state.state){
        case 'idle':
          return "/src/assets/idle.svg";
        case 'challenging someone':
          return "/src/assets/challenging.svg";
        case 'being challenged':
          return "/src/assets/challenged.svg";
        case 'in game':
          return "/src/assets/in_game.svg";
      }
   }
  },
  props: {
    nickname: { required: true, type: String},
    state: {required: true, type: Object},
    id: {required: true, type: String},
  },
  methods: {
    emitChallenge(nickname) {
      this.$emit('challenging', nickname)
    },
  },
  emits: ["challenging"]
}
</script>

<style>
.player-item {
  padding: 10px;
  background: #f8f8f8;
  margin-bottom: 5px;
  width: 100%;
}
</style>

<style scoped>
td{
  height: 30px;
}

.table-icon {
  height: 25px;
  margin-top: 5px;
}

.username-column .table-icon{
  margin-right: 20px;
}

.button-6 {
  margin:0;
}

.challenge-column{
  width: 50px;
}

.state-column {
  width: 20px;
}
</style>