export const ShellEnvPlugin = async () => {
  return {
    "shell.env": async (_input, output) => {
      Object.assign(output.env, {
        GIT_PAGER: "/usr/bin/cat",
      })
    },
  }
}
