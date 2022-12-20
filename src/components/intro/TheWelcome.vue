<script setup>
import WelcomeItem from './WelcomeItem.vue'
import TutorialIcon from '../icons/IconDocumentation.vue'
import PlayIcon from '../icons/IconTooling.vue'
import ContactIcon from '../icons/IconSupport.vue'
</script>

<template>
  <WelcomeItem>
    <template #icon>
      <TutorialIcon />
    </template>
    <template #heading>Tutorial</template>

    Check out the
    <router-link to="/tutorial">tutorial</router-link>
    to learn how to play the game.
  </WelcomeItem>

  <WelcomeItem>
    <template #icon>
      <PlayIcon />
    </template>
    <template #heading>Play</template>

    If you understand the rules, see if you can <router-link to="/play">find</router-link> an opponent.
  </WelcomeItem>

  <WelcomeItem>
    <template #icon>
      <ContactIcon />
    </template>
    <template #heading>Contact</template>

    I made this. This is me:
  </WelcomeItem>
</template>
