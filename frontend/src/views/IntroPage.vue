<script setup>
import HelloWorld from '../components/intro/Intro.vue'
import TheWelcome from '../components/intro/TheWelcome.vue'
</script>

<template>
  <div id="intro_wrapper">
    <header>
      <img alt="psygomoku logo" class="logo" src="../assets/skull.svg" width="200" height="200" />

      <div class="wrapper">
        <HelloWorld />
      </div>
    </header>

    <main>
      <TheWelcome />
    </main>
  </div>
</template>

<style scoped>
header {
  line-height: 1.5;
}

.logo {
  display: block;
  margin: 0 auto 2rem;
}

@media (min-width: 1024px) {
  header {
    display: flex;
    place-items: center;
    padding-right: calc(var(--section-gap) / 2);
  }

  .logo {
    margin: 0 2rem 0 0;
  }

  header .wrapper {
    display: flex;
    place-items: flex-start;
    flex-wrap: wrap;
  }
}
</style>
