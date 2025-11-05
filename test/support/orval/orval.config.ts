import { defineConfig } from "orval"

export default defineConfig({
  orvalApi: {
    input: "../../../samples/orval-api.json",
    output: {
      baseUrl: { getBaseUrlFromSpecification: true },
      mode: "split",
      target: "src/client",
      client: "axios",
      mock: false,
      clean: true,
    },
    hooks: {
      afterAllFilesWrite: "prettier --write src orval.config.ts",
    },
  },
})
