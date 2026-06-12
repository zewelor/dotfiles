const shellEnv = {
  GIT_PAGER: "cat",
}

export const ShellEnvPlugin = async () => {
  return {
    "shell.env": async (_input, output) => {
      Object.assign(output.env, shellEnv)
    },
  }
}
