import {reactive} from "vue";

export const current_user = reactive({
    nickname: '<unknown>',
    other_nickname: null,
    is_white: undefined
})
