# Project instructions

## Architecture
- Put reusable server logic in Services. Services exist only on the server.
- Put client logic in Controllers and name client modules with the Controller suffix.
- Put UI controllers in Controllers/UI; keep other client controllers in Controllers.
- Controllers listen to remote events and call services.
- Managers connect gameplay interactions.
- Keep authoritative gameplay state on the server.
- Animations, tweens and visual effects go on the client.

## Networking
- Use Knit Events for networking
- If possible use UnreliableRemoteEvents for constants firing events that are not important
- UnreliableRemoteEvents should be created in the ReplicatedStorage.Assets.Events

## Code style

- Use Luau and follow existing naming conventions.
- Keep functions small and focused.
- Write each `require` argument using the full module path, starting from a Roblox service variable defined with `game:GetService()`. Do not use intermediate folder aliases or start the path with `game`.
- Use the `workspace` global when refering to the workspace, dont use `game.Workspace` nor use `game:GetService("Workspace")`
- Roblox automatically disconnects all connections of all events of instances that get destroyed. There's no need to manually clear connections in this case.
- Add blank lines between sections of the same function

## Scalability
- Consider possible reuse of functions, types and structures when implementing new features. Create new services to make the code easier to reuse and scale.

## Type Checking
- Declare the types of function parameters and return types
- Typecast the result of `WaitForChild` and `FindFirstChild` to the appropriate subclass when it will later be used to access a property or method not defined on `Instance`.
- Prefer using `FindFirstChildWhichIsA` instead of `FindFirstChild` when applicable
- When referring to the HumanoidRootPart of a character, use `Character.PrimaryPart` instead of `Character:FindFirstChild("HumanoidRootPart")`
- Don't declare the return type of functions that dont return anything

## Game Instances
- For tasks that require the use of instances inside studio, use the MCP server for better understanding of the game's hierarchy

## Performance
- Prefer using `QueryDescendants` instead of `GetDescendants` + `if` statement
- Don't use Heartbeat:Wait() or task.wait() while loops when its possible to solve the problem with just events.

## Validation
- Run Selene on changed scripts.
- Verify the project builds with Rojo.
