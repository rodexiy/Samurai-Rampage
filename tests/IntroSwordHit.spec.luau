return function(Source: string): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end

	local Vector = setmetatable({}, {
		__add = function(Self: any): any
			return Self
		end,
		__unm = function(Self: any): any
			return Self
		end,
	})
	local function Actor(Attributes: { [string]: any }): any
		return {
			GetAttribute = function(_: any, Name: string): any
				return Attributes[Name]
			end,
			SetAttribute = function(_: any, Name: string, Value: any)
				Attributes[Name] = Value
			end,
			FindFirstChild = function(): any
				return nil
			end,
			GetPivot = function(): any
				return { Position = Vector, LookVector = Vector }
			end,
		}
	end

	local function Attack(Box: boolean, Protected: boolean, Immune: boolean, Accept: boolean): any
		local Attacker = Actor({ Stance = "Beginner", ComboCounter = 1 })
		local Target = Actor({ IntroTutorialProtected = Protected, ForceField = Immune })
		local Result = { Hits = {}, DamageChecks = 0, DamageCalculations = 0, TalentTargets = 0 }
		local function Hitbox(Callback: (...any) -> ())
			Callback(Target, { Position = Vector }, { Position = Vector, Normal = Vector })
		end
		local function Noop() end
		local Services = {
			WeaponService = {
				IncreaseComboCounter = Noop,
				PlayM1Animation = function(): (any, any)
					return { Length = 1, AdjustSpeed = Noop }, {
						GetAttribute = function(): any
							return nil
						end,
					}
				end,
				DidCancel = function(): boolean
					return false
				end,
				ShowSlash = Noop,
			},
			AnimationService = {
				StopAnimationFind = Noop,
				StopAttackAnimations = Noop,
				GetAnimationFind = function(): boolean
					return true
				end,
			},
			StaminaService = { RemoveStamina = Noop },
			ValuesService = {
				GetWeaponStaminaCost = function(): number
					return 1
				end,
			},
			DebounceService = { AddDebounce = Noop },
			ClothService = {
				StartSwing = function(): any
					return Noop
				end,
			},
			HitboxService = {
				CreatePartHitbox = function(_: any, _: any, _: any, Callback: any)
					Hitbox(Callback)
				end,
				CharacterRaycastHitbox = function(_: any, _: any, _: any, Callback: any)
					Hitbox(Callback)
				end,
			},
			DamageService = {
				CanDamage = function(): boolean
					Result.DamageChecks += 1
					return not Protected and not Immune
				end,
				CalculateDamage = function(): number
					Result.DamageCalculations += 1
					return 7
				end,
			},
			TalentService = {
				GetAttackSpeed = function(): number
					return 1
				end,
				BeginAttack = function(): any
					return {}
				end,
				ActivateAttack = function(): boolean
					return true
				end,
				AcceptTarget = function(): boolean
					Result.TalentTargets += 1
					return Accept
				end,
				GetPostureBonus = function(): number
					return 0
				end,
			},
			HitService = {
				NormalHit = function(_: any, HitTarget: any, HitAttacker: any, Damage: number, Data: any): string
					table.insert(
						Result.Hits,
						{ Target = HitTarget, Attacker = HitAttacker, Damage = Damage, Data = Data }
					)
					return "Deflect"
				end,
				MeleeHit = function(Self: any, HitTarget: any, HitAttacker: any, Damage: number, Data: any, Resolve: (string?) -> ())
					Resolve(Self:NormalHit(HitTarget, HitAttacker, Damage, Data))
				end,
			},
		}
		local Knit = {
			GetService = function(Name: string): any
				return Services[Name] or {}
			end,
		}
		local Storage = {
			Packages = { Knit = "Knit" },
			Shared = {
				Validate = "Validate",
				Utils = { GetModelMass = "Mass" },
				Index = { Stances = "Stances" },
			},
		}
		local Config = {
			HitboxType = if Box then "Box" else "Ray",
			HitboxDelay = 0,
			EnableSwordTrail = false,
			PlaySwingSound = false,
		}
		local Run = assert(loadstring(Source))
		setfenv(
			Run,
			setmetatable({
				game = {
					GetService = function(_: any, Name: string): any
						return if Name == "ReplicatedStorage" then Storage else {}
					end,
				},
				require = function(Name: string): any
					if Name == "Knit" then
						return Knit
					end
					if Name == "Validate" then
						return {
							CanAttack = function(): boolean
								return true
							end,
						}
					end
					if Name == "Stances" then
						return { Beginner = { M1 = { Config } } }
					end
					return function(): number
						return 1
					end
				end,
				tick = function(): number
					return 100
				end,
				task = {
					delay = function(_: number, Callback: () -> ())
						Callback()
					end,
				},
				CFrame = {
					new = function(): any
						return {}
					end,
				},
			}, { __index = getfenv() })
		)
		Run().Attack(Attacker, { Server = {} })

		return Result
	end

	for _, Box in { false, true } do
		local Tutorial = Attack(Box, true, false, true)
		Check(#Tutorial.Hits == 1, "Protected boss hit reaches the tutorial from both hitbox types")
		Check(Tutorial.Hits[1].Damage == 0, "Lesson contact must not apply health damage")
		Check(
			Tutorial.Hits[1].Data.By == "Weapon" and Tutorial.Hits[1].Data.Action == "Attack",
			"Preserve lesson action context"
		)
		Check(
			Tutorial.DamageCalculations == 0 and Tutorial.TalentTargets == 0,
			"Lesson contact does not consume talent effects"
		)
		local Immune = Attack(Box, false, true, true)
		Check(#Immune.Hits == 0 and Immune.DamageCalculations == 0, "Ordinary invulnerability remains effective")
		local Rejected = Attack(Box, false, false, false)
		Check(#Rejected.Hits == 0, "Ordinary talent target validation remains effective")
		local Normal = Attack(Box, false, false, true)
		Check(#Normal.Hits == 1 and Normal.Hits[1].Damage == 7, "Ordinary sword contact keeps calculated damage")
		Check(Normal.TalentTargets == 1 and Normal.DamageCalculations == 1, "Ordinary sword contacts still use talents")
	end

	return string.format("IntroSwordHit: %d checks passed", Checks)
end
