local IntroCutsceneConfig = {
    Enabled = true,
    ShipName = "Ship",
    ShipsFolderName = "IntroCutsceneShips",
    PlayerSpawnPath = {"Spawn", "Player"},
    PlayerSpawnOffset = CFrame.identity,
    EnemySpawnPath = {"Spawn", "Enemy"},
    EnemySpawnOffset = CFrame.new(0, 1, 0),
    BossName = "Yamarashi",
    BossRunner = "Yamarashi",
    BossConfig = "YamarashiTutorial",
    StarterWeapon = "BasicKatana",
    CombatTutorial = {
        Enabled = true,
        PauseBeforeHit = -0.1,
        ParryRecoveryTime = 0.5,
        EnemyParryRecovery = 0.85,
        CounterattackTimeout = 10,
        ReactionReleaseTime = 0.12,
        ParryWindow = 0.65,
        DodgeWindow = 0.65,
        RecoveryTime = 1.85,
        MaximumDistance = 24,
        AmbienceVolume = 0.2,
    },
    Tsunami = {
        PlayerHealthRatio = 1 / 3,
        BossHealthRatio = 1 / 2,
        HeavyParryTime = 0.85,
        WarningTime = 3,
        ModelName = "Tsunami",
        ApproachTime = 5,
        ImpactFadeTime = 0,
        CombatMusicFadeTime = 2,
        SoundId = "rbxassetid://109125037851677",
        SoundVolume = 1,
        CameraBackOffset = 12,
        CameraHeight = 1,
        CameraLookDistance = 70,
        CameraLookHeight = 30,
        InitialFov = 75,
        ImpactFov = 90,
        Umibozu = {
            ModelName = "Umibozu",
            Scale = 3,
            YawDegrees = 0,
            ForwardTiltDegrees = 25,
            BehindWaveGap = 0,
            VerticalOffset = 40,
            RiseTime = 3,
            HoldTime = 2,
        },
        CameraShake = {
            Enabled = true,
            PositionAmplitude = 0.45,
            RotationDegrees = 2.5,
            Frequency = 12,
            WarningStrength = 0.35,
            RampPower = 2
        },
        WaveGap = 180,
        WaveVerticalOffset = -12,
        -- Distance the front edge travels past the camera at the end of ApproachTime.
        WaveEndPastCamera = 0
    },

    ShipAmbience = {
        CreakSoundIds = {"rbxassetid://94382368532445", "rbxassetid://103732460204000", "rbxassetid://85577640157855"},
        FireSoundId = "rbxassetid://2787093357",
        CreakVolume = 0.3,
        FireVolume = 0.15,
        MinimumCreakInterval = 3,
        MaximumCreakInterval = 7,
        MaximumCreakLifetime = 60
    },

    Opening = {
        FadeTime = 1.25,
        EstablishTime = 2.75,
        EstablishOffset = Vector3.new(200, 200, 300),
        EstablishFocus = Vector3.new(0, 55, -25),
        EstablishFov = 38,
        BossCameraOffset = Vector3.new(0, 2.8, -12),
        BossFov = 52,
        BossLineTime = 5.5,
        BossLine = "Ha ha ha! What are you going to do now? Your entire crew is already dead.",
        PlayerCameraOffset = Vector3.new(9, 1.8, 0),
        PlayerCameraTravel = 4,
        PlayerFov = 50,
        PlayerLineTime = 3.25,
        PlayerLine = "All that's left is to finish you off.",
        TransitionTime = 1.25,
        CombatZoom = 8,
        DrawTime = 1
    },

    -- World height of the ship's pivot (Ship.Base), relative to the ocean at Y = 0.
    ShipHeight = 0,
    ShipRotationDegrees = 0,
    AnchorShip = true,

    -- The first column is moved farther out if the map extends into this position.
    OceanOrigin = Vector3.new(6000, 0, 0),
    MapRootNames = {"Assets", "Map"},
    MinimumMapDistance = 3000,
    MinimumShipDistance = 2000,
    ShipsPerColumn = 8,

    ExclusionRadius = 450,
    IntrusionCheckInterval = 0.25,
    IntrusionKickMessage = "You entered another player's intro area. Please rejoin.",
    StreamTimeout = 5,

    StormLightingName = "Storm",
    Environment = {
        ClockTime = 20,
        CloudCover = 0.8,
        CloudColor = Color3.fromRGB(39, 39, 39)
    },

    Lightning = {
        MinimumInterval = 10,
        MaximumInterval = 18,
        MinimumRadius = 500,
        MaximumRadius = 900,
        SurfaceY = 0
    },

    CameraSway = {
        Enabled = true,
        RollDegrees = 2.5,
        PitchDegrees = 1.2,
        RollPeriod = 6,
        PitchPeriod = 8.5,
        BlendResponse = 3
    },

    WakeUp = {
        SpawnPath = {"Important", "BeachSpawn"},
        BlackoutTime = 5,
        FadeTime = 1.25,
        AnimationId = "rbxassetid://118381390979531",
        AnimationDuration = 5,
        AnimationTimeout = 30,
        CameraHeight = 18,
        CameraFov = 55,
        GameplayOffset = Vector3.new(0, 4, 15),
        GameplayFocusHeight = 1.5,
        TransitionTime = 2
    }
}

return IntroCutsceneConfig
