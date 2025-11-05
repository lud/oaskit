import axios from "axios"
import { getOaskitOrvalAPI } from "./client/oaskitOrvalAPI"
const api = getOaskitOrvalAPI()

axios.interceptors.request.use((request) => {
  console.log("Starting Request", axios.getUri(request))
  return request
})

const x = await api.testArrays({ "simple_explode_integers[]": [1, 2, 3] })

console.log(JSON.stringify(x.data, null, "  "))
