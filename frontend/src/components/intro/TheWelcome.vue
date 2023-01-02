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
    <template #heading><router-link to="/tutorial">Tutorial</router-link></template>

    Check out the tutorial to learn how to play the game.
  </WelcomeItem>

  <WelcomeItem>
    <template #icon>
      <PlayIcon />
    </template>
    <template #heading><router-link to="/play">Play</router-link></template>

    If you understand the rules, see if you can find an opponent.
  </WelcomeItem>

  <WelcomeItem>
    <template #icon>
      <ContactIcon />
    </template>
    <template #heading>Contact</template>

    Check out the repo:
    <br>
    <a target="_blank" href="https://github.com/CaptainTrojan/psygomoku">https://github.com/CaptainTrojan/psygomoku</a>
    <br>

    If you find any bugs, please report them <a target="_blank" href="https://github.com/CaptainTrojan/psygomoku/issues/new?assignees=&labels=&template=bug_report.md&title=">here.</a>
  </WelcomeItem>
</template>
