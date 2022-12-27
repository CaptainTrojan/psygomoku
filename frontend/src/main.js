import IntroPage from '@/views/IntroPage.vue'
import TutorialPage from '@/views/TutorialPage.vue'
import App from './App.vue'
import './assets/main.css'
import {createApp} from "vue";
import {createRouter, createWebHashHistory} from "vue-router";
import PlayPage from "@/views/PlayPage.vue";
import {PromiseDialog} from "vue3-promise-dialog";


const routes = [
    { path: '/', component: IntroPage},
    { path: '/tutorial', component: TutorialPage},
    { path: '/play', component: PlayPage},
]

const router = createRouter({
    history: createWebHashHistory(),
    routes
})

createApp(App)
    .use(router)
    .use(PromiseDialog)
    .mount('#app')
