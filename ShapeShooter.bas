'$Dynamic
'$Include:'lib\vector\vector.bi'
Randomize Timer
Screen _NewImage(640, 640, 32)
_Title "Shape Shooter"
Color -1, 0

Dim Shared BigFont&, Font&
Font& = _LoadFont("lucon.ttf", 16)
BigFont& = _LoadFont("consola.ttf", 32, "MONOSPACE")
_Font Font&

Type Entity
    As _Unsigned _Byte Alive, Type
    As Vec2 Position
    As Single Angle, MaxSpeed, Health, MaxHealth, StyleAngle, HitRadius
    As Integer MoneyValue, MoveCooldown, ShootCooldown, SetMoveCooldown, SetShootCooldown
    As _Unsigned Long SpecialData
End Type
Type Bullet
    As _Unsigned _Byte Alive
    As Vec2 Position, Velocity
    As _Unsigned Long Target
End Type
Type Money
    As _Unsigned _Byte Alive
    As Vec2 Position
    As _Unsigned Integer Value
End Type

Dim Shared As Vec2 Camera

Dim Shared As Single CosTable(0 To 360), SinTable(0 To 360)
For T! = 0 To 360: CosTable(T!) = Cos(_D2R(T!)): SinTable(T!) = Sin(_D2R(T!)): Next T!

Dim Shared As Entity Player
NewVec2 Player.Position, _Width / 2, _Height / 2
Player.MaxSpeed = 2.5
Player.MaxHealth = 10: Player.Health = Player.MaxHealth
Dim Shared PlayerHelper, PlayerShootCooldown: PlayerHelper = 1: PlayerShootCooldown = 30

Const D2R_90 = _D2R(90)

Dim Shared As _Unsigned Long RadialCharge, LaserCharge
Dim Shared As Single RadialWaveDamage, BulletsDamage, LaserDamage
RadialWaveDamage = 0.25: BulletsDamage = 1: LaserDamage = 1

Dim Shared Helpers(255) As Entity, NewHelperID As _Unsigned _Byte

Dim Shared Enemies(1023) As Entity, NewEnemyID As _Unsigned _Bit * 10
Dim Shared LatestEnemyID As _Unsigned Integer
Const MODE_SIMULATE = 1
Const MODE_BULLETBEHAVIOUR = 2

Dim Shared Bullets(1023) As Bullet, NewBulletID As _Unsigned _Bit * 10
Dim Shared EnemyBullets(1023) As Bullet, NewEnemyBulletID As _Unsigned _Bit * 10

Dim Shared Points(1023) As Money, NewMoneyID As _Unsigned _Bit * 10
Dim Shared As _Unsigned Long PlayerMoney

Const Player_Max_Radius = 20
Const CollisionResolutionDistance = 20
Const BulletSpeed = 20

Const RadialChargeRadius = 3
Const LaserChargeTime = 0.6

Dim As _Unsigned _Byte EnemySpawnCooldown
Dim As _Unsigned Integer BossSpawnCooldown: BossSpawnCooldown = 3600

Dim Shared As Double Hardness

Dim Shared As Vec2 MousePosition

Dim Shared As _Unsigned Long TimeCounter

Dim Shared As _Unsigned Long Score

Do
    Cls , _RGB32(0, 0, 31)
    _Limit 60
    While _MouseInput: Wend
    NewVec2 MousePosition, _MouseX, _MouseY: Vec2Add MousePosition, Camera

    DrawBackground: DrawHelper
    DrawEnemies
    DrawBullets: DrawEnemyBullets
    DrawMoney
    DrawRadialAttack 0: DrawLaserAttack 0
    If Player.Health <= 0 Then
        _Font BigFont&
        CenterPrint _Width / 2, _Height / 2 - 16, "Play Again (Y/N)"
        Select Case _KeyHit
            Case 89, 121: Run
            Case 27, 78, 110: Exit Do
        End Select
        CenterPrint _Width / 2, 16, "Score:" + Str$(Score)
        Print "Coins:" + Str$(PlayerMoney)
        _Font Font&
    Else
        DrawPlayer
        Score$ = "Score:" + Str$(Score): _Font BigFont&: CenterPrint _Width / 2, 16, Score$: Print "Coins:" + Str$(PlayerMoney): _Font Font&
        RightPrint 8, "Health:" + Str$(Player.Health) + "/" + _Trim$(Str$(Player.MaxHealth))
        _PrintString (0, 32), "Radial Attack:" + Str$(Int(RadialCharge)) + "%"
        _PrintString (0, 48), "Laser Attack:" + Str$(Int(LaserCharge)) + "%"
    End If

    _Display

    Camera.X = Camera.X + (Player.Position.X - Camera.X - _Width / 2) / 16
    Camera.Y = Camera.Y + (Player.Position.Y - Camera.Y - _Height / 2) / 16

    If EnemySpawnCooldown = 0 Then
        EnemySpawnCooldown = Max(10, 60 - Hardness)
        NewEnemy Int(Rnd * Min(9, 1 + ceil(Hardness))) + 1
    Else EnemySpawnCooldown = EnemySpawnCooldown - Sgn(EnemySpawnCooldown)
    End If
    If BossSpawnCooldown = 0 Then
        BossSpawnCooldown = Max(180, 3600 - 600 * Hardness)
        NewBossEnemy Int(Rnd * Min(6, ceil(Hardness))) + 1
    Else BossSpawnCooldown = BossSpawnCooldown - Sgn(BossSpawnCooldown)
    End If

    If Player.Health > 0 Then
        KEY_W = _KeyDown(87) Or _KeyDown(119) Or _KeyDown(18432)
        KEY_S = _KeyDown(83) Or _KeyDown(115) Or _KeyDown(20480)
        KEY_A = _KeyDown(65) Or _KeyDown(97) Or _KeyDown(19200)
        KEY_D = _KeyDown(68) Or _KeyDown(100) Or _KeyDown(19712)
        Player.Position.X = Player.Position.X + Player.MaxSpeed * (KEY_A - KEY_D)
        Player.Position.Y = Player.Position.Y + Player.MaxSpeed * (KEY_W - KEY_S)

        If (_KeyDown(32) Or _MouseButton(1)) And Player.ShootCooldown = 0 Then
            Player.ShootCooldown = PlayerShootCooldown
            NewBullet Player.Position, Vec2Angle(Player.Position, MousePosition)
        End If
        Player.ShootCooldown = Player.ShootCooldown - Sgn(Player.ShootCooldown)

        KeyHit = _KeyHit
        Select Case KeyHit
            Case 27: DrawMenu
            Case 82, 114: 'Radial Attack
                If RadialCharge >= 25 Then DrawRadialAttack RadialCharge * RadialChargeRadius: RadialCharge = 0
            Case 67, 99: 'Laser Attack
                If LaserCharge >= 25 Then DrawLaserAttack LaserCharge * LaserChargeTime: LaserCharge = 0
            Case 78, 110: 'New Helper
                If PlayerMoney >= 100 Then NewHelper: PlayerMoney = PlayerMoney - 100
        End Select

        If HardnessIncreaseDelay = 0 Then
            HardnessIncreaseDelay = 60
            Hardness = Hardness + 0.01
        Else
            HardnessIncreaseDelay = HardnessIncreaseDelay - 1
        End If
        TimeCounter = ClampCycle(0, TimeCounter + 1, 59)
    End If
    _KeyClear
Loop
System

Sub DrawBackground Static
    For X = ModFloor(-Camera.X, 64) To _Width + 64 Step 64
        Line (X, 0)-(X, _Height - 1), _RGB32(31)
    Next X
    For Y = ModFloor(-Camera.Y, 64) To _Height + 64 Step 64
        Line (0, Y)-(_Width - 1, Y), _RGB32(31)
    Next Y
End Sub

Sub DrawMenu Static
    Static As _Unsigned Long Cost_MaxSpeed, Cost_Helper, Cost_FireSpeed, Cost_RadialWave, Cost_Bullets, Cost_Laser
    Static As _Unsigned Integer Level_MaxSpeed, Level_Helper, Level_FireSpeed, Level_RadialWave, Level_Bullets, Level_Laser
    If Cost_MaxSpeed = 0 Then Cost_MaxSpeed = 25
    If Cost_Helper = 0 Then Cost_Helper = 1000
    If Cost_FireSpeed = 0 Then Cost_FireSpeed = 25
    If Cost_RadialWave = 0 Then Cost_RadialWave = 500
    If Cost_Bullets = 0 Then Cost_Bullets = 250
    If Cost_Laser = 0 Then Cost_Laser = 250
    Do
        Cls , _RGB32(0, 0, 31)
        _Limit 60
        While _MouseInput: Wend
        _Font BigFont&: CenterPrint _Width / 2, 48, "Coins:" + Str$(PlayerMoney): _Font Font&
        If DrawMenuCard(0.25 * _Width, 0.4 * _Height, "Speed", "Level" + Str$(Level_MaxSpeed + 1), _Trim$(Str$(Cost_MaxSpeed)), AnimationData1~%%, IIF(PlayerMoney >= Cost_MaxSpeed, -1, _RGB32(255, 0, 0))) And PlayerMoney >= Cost_MaxSpeed Then
            PlayerMoney = PlayerMoney - Cost_MaxSpeed
            Player.MaxSpeed = Player.MaxSpeed + 0.1
            Cost_MaxSpeed = Cost_MaxSpeed + 25
            Level_MaxSpeed = Level_MaxSpeed + 1
        End If
        If DrawMenuCard(0.5 * _Width, 0.4 * _Height, "Helper", "Level" + Str$(Level_Helper + 1), _Trim$(Str$(Cost_Helper)), AnimationData2~%%, IIF(PlayerMoney >= Cost_Helper, -1, _RGB32(255, 0, 0))) And PlayerMoney >= Cost_Helper Then
            PlayerMoney = PlayerMoney - Cost_Helper
            PlayerHelper = PlayerHelper + 1
            Level_Helper = Level_Helper + 1
            Cost_Helper = Level_Helper * 2000
        End If
        If DrawMenuCard(0.75 * _Width, 0.4 * _Height, "Fire", "Level" + Str$(Level_FireSpeed + 1), _Trim$(Str$(Cost_FireSpeed)), AnimationData3~%%, IIF(PlayerMoney >= Cost_FireSpeed, -1, _RGB32(255, 0, 0))) And PlayerMoney >= Cost_FireSpeed Then
            PlayerMoney = PlayerMoney - Cost_FireSpeed
            Level_FireSpeed = Level_FireSpeed + 1
            PlayerShootCooldown = 30 / Level_FireSpeed
            Cost_FireSpeed = Cost_FireSpeed * 2
        End If
        If DrawMenuCard(0.25 * _Width, 0.7 * _Height, "Radial Wave", "Level" + Str$(Level_RadialWave + 1), _Trim$(Str$(Cost_RadialWave)), AnimationData4~%%, IIF(PlayerMoney >= Cost_RadialWave, -1, _RGB32(255, 0, 0))) And PlayerMoney >= Cost_RadialWave Then
            PlayerMoney = PlayerMoney - Cost_RadialWave
            Level_RadialWave = Level_RadialWave + 1
            RadialWaveDamage = RadialWaveDamage + 0.25
            Cost_RadialWave = Cost_RadialWave * 2
        End If
        If DrawMenuCard(0.5 * _Width, 0.7 * _Height, "Bullets", "Level" + Str$(Level_Bullets + 1), _Trim$(Str$(Cost_Bullets)), AnimationData5~%%, IIF(PlayerMoney >= Cost_Bullets, -1, _RGB32(255, 0, 0))) And PlayerMoney >= Cost_Bullets Then
            PlayerMoney = PlayerMoney - Cost_Bullets
            Level_Bullets = Level_Bullets + 1
            BulletsDamage = BulletsDamage + 1
            Cost_Bullets = Cost_Bullets + 250
        End If
        If DrawMenuCard(0.75 * _Width, 0.7 * _Height, "Laser", "Level" + Str$(Level_Laser + 1), _Trim$(Str$(Cost_Laser)), AnimationData6~%%, IIF(PlayerMoney >= Cost_Laser, -1, _RGB32(255, 0, 0))) And PlayerMoney >= Cost_Laser Then
            PlayerMoney = PlayerMoney - Cost_Laser
            Level_Laser = Level_Laser + 1
            LaserDamage = LaserDamage + 1
            Cost_Laser = Cost_Laser * 2
        End If
        _Display
    Loop Until _KeyHit = 27
End Sub
Function DrawMenuCard (X As Integer, Y As Integer, Label$, Line1$, Line2$, AnimationData As _Byte, Colour As Long) Static
    Dim As Vec2 A, B
    A.X = X - 64: A.Y = Y - 64
    B.X = X + 64: B.Y = Y + 64
    Line (A.X - AnimationData, A.Y - AnimationData)-(B.X + AnimationData, B.Y + AnimationData), Colour, B
    CenterPrint X, Y - 32, Label$
    CenterPrint X, Y, Line1$
    CenterPrint X, Y + 16, Line2$
    If MouseInBox(A, B) Then
        AnimationData = AnimationData + Sgn(5 - AnimationData)
        If _MouseButton(1) Then DrawMenuCard = -1: WaitForMouseButton
    Else
        AnimationData = AnimationData - Sgn(AnimationData)
    End If
End Function

Sub NewHelper Static
    Helpers(NewHelperID).Alive = -1
    Helpers(NewHelperID).Type = 1
    Helpers(NewHelperID).MaxHealth = PlayerHelper * 5 + 5
    Helpers(NewHelperID).Health = PlayerHelper * 5 + 5
    Helpers(NewHelperID).SetShootCooldown = 15
    Helpers(NewHelperID).MaxSpeed = PlayerHelper * 2.5
    Helpers(NewHelperID).HitRadius = 9 + PlayerHelper
    Helpers(NewHelperID).MoveCooldown = 3600
    Helpers(NewHelperID).Position = Player.Position
    NewHelperID = NewHelperID + 1
End Sub
Sub DrawHelper Static
    MinDisBossID = 0
    MaxHealth = 0
    For I = 0 To 1023
        If Enemies(I).Alive = 0 Then _Continue
        If Enemies(I).Health > Enemies(MaxHealth).Health Then
            MaxHealth = I
        ElseIf Vec2Dis(Enemies(MinDisBossID).Position, Player.Position) > Vec2Dis(Enemies(I).Position, Player.Position) Then
            MinDisBossID = I
        End If
    Next I
    For I = 0 To 255
        If Helpers(I).Alive = 0 Then Exit Sub
        Select Case Helpers(I).Type
            Case 1: If Enemies(Helpers(I).SpecialData).Alive = 0 Then Helpers(I).SpecialData = IIF(MaxHealth, MaxHealth, MinDisBossID)
                Helpers(I).ShootCooldown = ClampCycle(0, Helpers(I).ShootCooldown - 1, Helpers(I).SetShootCooldown)
                If Helpers(I).ShootCooldown = 0 And Enemies(Helpers(I).SpecialData).Alive Then NewBullet Helpers(I).Position, Vec2Angle(Helpers(I).Position, Enemies(Helpers(I).SpecialData).Position)
                Circle (Helpers(I).Position.X - Camera.X, Helpers(I).Position.Y - Camera.Y), Helpers(I).HitRadius, -1
        End Select
        Helpers(I).MoveCooldown = Helpers(I).MoveCooldown - Sgn(Helpers(I).MoveCooldown)
        Helpers(I).Alive = Helpers(I).MoveCooldown <> 0
        Helpers(I).Position.X = Helpers(I).Position.X + Sgn(Enemies(Helpers(I).SpecialData).Position.X - Helpers(I).Position.X)
        Helpers(I).Position.Y = Helpers(I).Position.Y + Sgn(Enemies(Helpers(I).SpecialData).Position.Y - Helpers(I).Position.Y)
    Next I
End Sub

Sub NewEnemy (__Type As _Unsigned _Byte) Static
    If Enemies(NewEnemyID).Alive Then
        For I = 0 To 1023
            If Enemies(I).Alive = 0 Then Exit For
        Next I
        If I = 1024 Then NewEnemyID = NewEnemyID + 1: Exit Sub
        NewEnemyID = I
    End If
    LatestEnemyID = NewEnemyID
    Enemies(NewEnemyID).Alive = -1
    Enemies(NewEnemyID).Type = __Type
    If Rnd > 0.5 Then
        NewVec2 Enemies(NewEnemyID).Position, Player.Position.X + RandomValuesInside * _Width, Player.Position.Y + RandomValuesOutside * _Height
    Else
        NewVec2 Enemies(NewEnemyID).Position, Player.Position.X + RandomValuesOutside * _Width, Player.Position.Y + RandomValuesInside * _Height
    End If
    Enemies(NewEnemyID).MaxHealth = __Type + Int(Hardness)
    Enemies(NewEnemyID).Health = Enemies(NewEnemyID).MaxHealth
    Enemies(NewEnemyID).MaxSpeed = 8 + Hardness - 2 * (__Type = 1)
    Enemies(NewEnemyID).HitRadius = 20
    Enemies(NewEnemyID).MoveCooldown = 60
    Enemies(NewEnemyID).ShootCooldown = 150
    Enemies(NewEnemyID).MoneyValue = Enemies(NewEnemyID).MaxHealth
    NewEnemyID = NewEnemyID + 1
End Sub
Sub NewBossEnemy (__Type As _Unsigned _Byte) Static
    Enemies(NewEnemyID).Alive = -1
    Enemies(NewEnemyID).Type = Clamp(65, __Type + 64, 70)
    If Rnd > 0.5 Then
        NewVec2 Enemies(NewEnemyID).Position, Player.Position.X + RandomValuesInside * _Width, Player.Position.Y + RandomValuesOutside * _Height
    Else
        NewVec2 Enemies(NewEnemyID).Position, Player.Position.X + RandomValuesOutside * _Width, Player.Position.Y + RandomValuesInside * _Height
    End If
    Enemies(NewEnemyID).MaxHealth = 10 * (__Type + Int(Hardness))
    Enemies(NewEnemyID).Health = Enemies(NewEnemyID).MaxHealth
    Enemies(NewEnemyID).MaxSpeed = 2 + Hardness - 2 * (__Type = 1)
    Enemies(NewEnemyID).HitRadius = 50
    Enemies(NewEnemyID).MoveCooldown = 60
    Enemies(NewEnemyID).ShootCooldown = 150
    Enemies(NewEnemyID).MoneyValue = Enemies(NewEnemyID).MaxHealth
    Enemies(NewEnemyID).SetMoveCooldown = SetMoveCooldown
    NewEnemyID = NewEnemyID + 1
End Sub

Sub DrawPlayer Static
    If PlayerImage& = 0 Then
        PlayerImage& = _NewImage(40, 40, 32)
        _Dest PlayerImage&
        Circle (20, 20), 16, -1
        Circle (20, 20), 20, -1
        Paint (38, 20), -1
        _Dest 0
    End If
    _PutImage (Player.Position.X - Camera.X - 20, Player.Position.Y - Camera.Y - 20), PlayerImage&
End Sub
Sub DrawEnemies Static
    Dim As Vec2 CurrentLinePosition
    Dim As _Unsigned Long I
    For I = 0 To 1023
        If Enemies(I).Alive = 0 Then _Continue
        Enemies(I).Angle = Vec2Angle(Enemies(I).Position, Player.Position)
        Select Case Enemies(I).Type
            Case 1: Enemy_1_Circle MODE_SIMULATE, I
            Case 2: Enemy_2_Square MODE_SIMULATE, I
            Case 3: Enemy_3_Triangle MODE_SIMULATE, I
            Case 4: Enemy_4_RoseCurve MODE_SIMULATE, I
            Case 5: Enemy_5_Pentagon MODE_SIMULATE, I
            Case 6: Enemy_6_Hexagon MODE_SIMULATE, I
            Case 7: Enemy_7_Hypocycloid MODE_SIMULATE, I
            Case 8: Enemy_8_Octagon MODE_SIMULATE, I
            Case 9: Enemy_9_Minion MODE_SIMULATE, I

            Case 65: Boss_1_Slow MODE_SIMULATE, I
            Case 66: Boss_2_Minion MODE_SIMULATE, I
            Case 67: Boss_3_Decagon MODE_SIMULATE, I
            Case 68: Boss_4_Absorber MODE_SIMULATE, I
            Case 69: Boss_5_Wave MODE_SIMULATE, I
            Case 70: Boss_6_Orbiter MODE_SIMULATE, I
        End Select
        Enemies(I).StyleAngle = Enemies(I).StyleAngle + 0.01
    Next I
End Sub
Sub CollisionResolutionByAngle (Position As Vec2, Angle!) Static
    Position.X = Position.X + Cos(Angle!) * CollisionResolutionDistance
    Position.Y = Position.Y + Sin(Angle!) * CollisionResolutionDistance
End Sub
Sub Enemy_1_Circle (Mode~%%, I As _Unsigned Long) Static
    If EnemyCircleImage& = 0 Then
        EnemyCircleImage& = _NewImage(31, 31, 32): _Dest EnemyCircleImage&: Circle (15, 15), 10, _RGB32(0, 127, 255): Circle (15, 15), 15, _RGB32(0, 127, 255): Paint (27, 15), _RGB32(0, 127, 255): _Dest 0
    End If
    Select Case Mode~%%
        Case MODE_SIMULATE: _PutImage (Enemies(I).Position.X - Camera.X - 20, Enemies(I).Position.Y - Camera.Y - 20), EnemyCircleImage&
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 120)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Enemy_2_Square (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: DesignRegularPolygon 4, Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y, Enemies(I).StyleAngle, 15, 16, _RGB32(0, 191, 63)
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 180)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Enemy_3_Triangle (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: DesignRegularPolygon 3, Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y, Enemies(I).StyleAngle, 14, 15, _RGB32(255, 0, 255)
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 240)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Enemy_4_RoseCurve (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: X = Enemies(I).Position.X - Camera.X: Y = Enemies(I).Position.Y - Camera.Y: For T! = 0 To 360: __T! = _D2R(T!) - Enemies(I).StyleAngle: __TC! = CosTable(T!): __TS! = SinTable(T!)
                L! = Cos(4 * __T!)
                __X1 = X + 13 * L! * __TC!
                __Y1 = Y + 13 * L! * __TS!
                __X2 = X + 15 * L! * __TC!
                __Y2 = Y + 15 * L! * __TS!
            Line (__X1, __Y1)-(__X2, __Y2), -1: Next T!
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 240)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Enemy_5_Pentagon (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: DesignRegularPolygon 5, Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y, Enemies(I).StyleAngle, 14, 15, _RGB32(255, 0, 255)
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 120)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Enemy_6_Hexagon (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: DesignRegularPolygon 6, Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y, Enemies(I).StyleAngle, 14, 15, _RGB32(255, 0, 255)
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 180)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Enemy_7_Hypocycloid (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: X = Enemies(I).Position.X - Camera.X: Y = Enemies(I).Position.Y - Camera.Y: For T! = 0 To 360: __T! = _D2R(T!) - Enemies(I).StyleAngle: __TC! = CosTable(T!): __TS! = SinTable(T!)
                L! = 1 - Cos(8 * __T!)
                __X1 = X + 10 * L! * __TC!
                __Y1 = Y + 10 * L! * __TS!
                __X2 = X + 12 * L! * __TC!
                __Y2 = Y + 12 * L! * __TS!
            Line (__X1, __Y1)-(__X2, __Y2), -1: Next T!
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 180)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Enemy_8_Octagon (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: DesignRegularPolygon 8, Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y, Enemies(I).StyleAngle, 14, 15, _RGB32(255, 0, 255)
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 180)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Enemy_9_Minion (Mode~%%, I As _Unsigned Long) Static
    If EnemyCircleImage& = 0 Then
        EnemyCircleImage& = _NewImage(31, 31, 32): _Dest EnemyCircleImage&: Circle (15, 15), 10, _RGB32(191, 0, 95): Circle (15, 15), 15, _RGB32(191, 0, 95): Paint (27, 15), _RGB32(191, 0, 95): _Dest 0
    End If
    Select Case Mode~%%
        Case MODE_SIMULATE: _PutImage (Enemies(I).Position.X - Camera.X - 20, Enemies(I).Position.Y - Camera.Y - 20), EnemyCircleImage&
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > 180 Then
                Enemies(I).Position.X = Enemies(I).Position.X + 5 * Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + 5 * Sin(Enemies(I).Angle)
            Else
                If Enemies(I).ShootCooldown = 0 Then NewEnemyBullet Enemies(I).Position, Enemies(I).Angle, 5
            End If
            Enemies(I).ShootCooldown = ClampCycle(0, Enemies(I).ShootCooldown - 1, 30)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Boss_1_Slow (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: X = Enemies(I).Position.X - Camera.X: Y = Enemies(I).Position.Y - Camera.Y
            DesignWaveCircle X, Y, Enemies(I).StyleAngle, 10, 42 + 8 * Cos(Enemies(I).StyleAngle), 50 + 8 * Sin(Enemies(I).StyleAngle), _RGB32(200, 0, 0)
            If Enemies(I).ShootCooldown = 0 Then
                For J = 1 To 6: NewEnemyBullet Enemies(I).Position, Enemies(I).StyleAngle + J * _Pi / 3, 1: Next J
            End If
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > Player_Max_Radius + Enemies(I).HitRadius And Enemies(I).MoveCooldown < 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).MoveCooldown = ClampCycle(-60, Enemies(I).MoveCooldown - 1, 240)
            Enemies(I).ShootCooldown = ClampCycle(0, Enemies(I).ShootCooldown - 1, 60)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Boss_2_Minion (Mode~%%, I As _Unsigned Long) Static
    Dim As Vec2 BulletPosition
    Select Case Mode~%%
        Case MODE_SIMULATE: X = Enemies(I).Position.X - Camera.X: Y = Enemies(I).Position.Y - Camera.Y
            DesignRegularPolygon 6, X, Y, Enemies(I).StyleAngle, 42, 50, _RGB32(34, 200, 34)
            R = Enemies(I).SpecialData / 60
            For T! = 0 To 359 Step 60: __T! = _D2R(T!) + Enemies(I).StyleAngle: __TC! = Cos(__T!): __TS! = Sin(__T!)
                __X1 = X + (50 + 2 * R) * __TC!: __Y1 = Y + (50 + 2 * R) * __TS!
            For __R = R - 1 To R: Circle (__X1, __Y1), __R, _RGB32(191, 0, 95): Next __R, T!
            Enemies(I).SpecialData = Enemies(I).SpecialData + 1
            If Enemies(I).SpecialData = 600 Then
                Enemies(I).SpecialData = 0
                For T! = 0 To 359 Step 60: __T! = _D2R(T!) - Enemies(I).StyleAngle: __TC! = Cos(__T!): __TS! = Sin(__T!)
                    NewEnemy 9: Enemies(LatestEnemyID).Position.X = X + 90 * __TC!: Enemies(LatestEnemyID).Position.Y = Y + 90 * __TS!
                Next T!
            End If
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If distance! > 300 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            If distance! < 180 Then
                Enemies(I).Position.X = Enemies(I).Position.X - Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y - Sin(Enemies(I).Angle)
            End If
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Boss_3_Decagon (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: DesignRegularPolygon 10, Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y, Enemies(I).StyleAngle, 42, 50, _RGB32(120, 0, 180)
            Circle (Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y), (900 - Enemies(I).ShootCooldown) / 25, _RGB32(120, 0, 180)
            If Enemies(I).ShootCooldown = 0 Then
                For J = 1 To 6: NewEnemy 9: Next J
            End If
            If (Enemies(I).ShootCooldown Mod 90) = 0 Then
                NewEnemyBullet Enemies(I).Position, Enemies(I).Angle, 5
            End If
            distance! = Vec2Dis(Player.Position, Enemies(I).Position)
            If distance! <= Player_Max_Radius + Enemies(I).HitRadius Then
                CollisionResolutionByAngle Player.Position, Enemies(I).Angle
                CollisionResolutionByAngle Enemies(I).Position, -Enemies(I).Angle
                Player.Health = Player.Health - 1
            End If
            If InRange(240, distance!, 300) = 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X - Cos(Enemies(I).Angle) * Sgn(270 - distance!)
                Enemies(I).Position.Y = Enemies(I).Position.Y - Sin(Enemies(I).Angle) * Sgn(270 - distance!)
            End If
            Enemies(I).ShootCooldown = ClampCycle(0, Enemies(I).ShootCooldown - 1, 900)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Boss_4_Absorber (Mode~%%, I As _Unsigned Long) Static
    Dim As Vec2 BulletPosition
    Select Case Mode~%%
        Case MODE_SIMULATE: X = Enemies(I).Position.X - Camera.X: Y = Enemies(I).Position.Y - Camera.Y
            DesignRegularPolygon 16, X, Y, Enemies(I).StyleAngle, 8, 16, _RGB32(0, 120, 255)
            DesignRegularPolygon 16, X, Y, Enemies(I).StyleAngle, Enemies(I).HitRadius - 24, Enemies(I).HitRadius, _RGB32(0, 120, 255)
            If Enemies(I).SpecialData = 1 Then
                Enemies(I).HitRadius = Enemies(I).HitRadius + (50 - Enemies(I).HitRadius)
                If Enemies(I).HitRadius = 50 Then Enemies(I).SpecialData = 0
            End If
            If Enemies(I).HitRadius >= 96 Then
                For T! = 0 To 359 Step 10: __T! = _D2R(T!) - Enemies(I).StyleAngle: __TC! = Cos(__T!): __TS! = Sin(__T!)
                    NewVec2 BulletPosition, Enemies(I).Position.X + 96 * __TC!, Enemies(I).Position.Y + 96 * __TS!
                    NewEnemyBullet BulletPosition, Vec2Angle(Enemies(I).Position, BulletPosition), 10
                Next T!
                Enemies(I).SpecialData = 1
            End If
            If Vec2Dis(Enemies(I).Position, Player.Position) > 30 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
        Case MODE_BULLETBEHAVIOUR: If Rnd > 0.9 Then Enemies(I).HitRadius = Enemies(I).HitRadius + 1
    End Select
End Sub
Sub Boss_5_Wave (Mode~%%, I As _Unsigned Long) Static
    Select Case Mode~%%
        Case MODE_SIMULATE: X = Enemies(I).Position.X - Camera.X: Y = Enemies(I).Position.Y - Camera.Y
            DesignRegularPolygon 24, X, Y, Enemies(I).StyleAngle, 42, 50, _RGB32(210, 210, 0)
            If Enemies(I).ShootCooldown < 0 Then
                Circle (X, Y), 50 - Enemies(I).ShootCooldown * 2, _RGB32(210, 210, 0, 255 + 2 * Enemies(I).ShootCooldown)
                If Vec2Dis(Enemies(I).Position, Player.Position) <= 50 - Enemies(I).ShootCooldown * 2 And Enemies(I).SpecialData = 0 Then
                    Player.Health = Player.Health - 1
                    Enemies(I).SpecialData = 1
                End If
            Else
                Circle (X, Y), (60 - Enemies(I).ShootCooldown) / 1.5, _RGB32(210, 210, 0)
                Enemies(I).SpecialData = 0
            End If
            If Vec2Dis(Enemies(I).Position, Player.Position) > 60 Then
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
            End If
            Enemies(I).ShootCooldown = ClampCycle(-120, Enemies(I).ShootCooldown - 1, 60)
        Case MODE_BULLETBEHAVIOUR: If Enemies(I).ShootCooldown > 0 Then Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub Boss_6_Orbiter (Mode~%%, I As _Unsigned Long) Static
    Dim As Vec2 BulletPosition
    Select Case Mode~%%
        Case MODE_SIMULATE: X = Enemies(I).Position.X - Camera.X: Y = Enemies(I).Position.Y - Camera.Y
            DesignRegularPolygon 3, X, Y, Enemies(I).Angle, 42, 50, _RGB32(255, 40, 90)
            distance! = Vec2Dis(Enemies(I).Position, Player.Position)
            If InRange(280, distance!, 320) = 0 Then
                Enemies(I).Position.X = Enemies(I).Position.X - Cos(Enemies(I).Angle) * Sgn(300 - distance!)
                Enemies(I).Position.Y = Enemies(I).Position.Y - Sin(Enemies(I).Angle) * Sgn(300 - distance!)
            Else
                Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle + D2R_90)
                Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle + D2R_90)
            End If
            If Enemies(I).ShootCooldown = 0 Then
                NewVec2 BulletPosition, Enemies(I).Position.X + 20 * Cos(Enemies(I).Angle), Enemies(I).Position.Y + 20 * Sin(Enemies(I).Angle)
                NewEnemyBullet BulletPosition, Enemies(I).Angle, 10
            End If
            Enemies(I).ShootCooldown = ClampCycle(-60, Enemies(I).ShootCooldown - 1, 60)
        Case MODE_BULLETBEHAVIOUR: Enemies(I).Health = Clamp(0, Enemies(I).Health - BulletsDamage, Enemies(I).MaxHealth)
    End Select
End Sub
Sub KillEntity (I As _Unsigned Long) Static
    NewMoney Enemies(I).Position, Enemies(I).MoneyValue
    Score = Score + Enemies(I).MoneyValue
    Select EveryCase Enemies(I).Type
        Case 9: Player.Health = Min(Player.Health + 1, Player.MaxHealth)
        Case 65, 66, 67: Player.MaxHealth = Player.MaxHealth + 1: Player.Health = Min(Player.Health + 5, Player.MaxHealth)
    End Select
End Sub

Sub NewBullet (Source As Vec2, Angle As Single) Static
    Bullets(NewBulletID).Alive = -1
    Bullets(NewBulletID).Position = Source
    NewVec2 Bullets(NewBulletID).Velocity, Cos(Angle), Sin(Angle)
    Vec2Multiply Bullets(NewBulletID).Velocity, BulletSpeed
    NewBulletID = NewBulletID + 1
End Sub
Sub DrawBullets Static
    Dim As _Unsigned Long I, J
    For I = 0 To UBound(Bullets)
        If Bullets(I).Alive = 0 Then _Continue
        Vec2Add Bullets(I).Position, Bullets(I).Velocity
        If Vec2Dis(Bullets(I).Position, Player.Position) >= _Width / 1.2 Then Bullets(I).Alive = 0: _Continue
        For J = 0 To 1023
            If Enemies(J).Alive And Vec2Dis(Bullets(I).Position, Enemies(J).Position) <= Enemies(J).HitRadius Then
                Bullets(I).Alive = 0
                Select Case Enemies(J).Type
                    Case 1: Enemy_1_Circle MODE_BULLETBEHAVIOUR, J
                    Case 2: Enemy_2_Square MODE_BULLETBEHAVIOUR, J
                    Case 3: Enemy_3_Triangle MODE_BULLETBEHAVIOUR, J
                    Case 4: Enemy_4_RoseCurve MODE_BULLETBEHAVIOUR, J
                    Case 5: Enemy_5_Pentagon MODE_BULLETBEHAVIOUR, J
                    Case 6: Enemy_6_Hexagon MODE_BULLETBEHAVIOUR, J
                    Case 7: Enemy_7_Hypocycloid MODE_BULLETBEHAVIOUR, J
                    Case 8: Enemy_8_Octagon MODE_BULLETBEHAVIOUR, J
                    Case 9: Enemy_9_Minion MODE_BULLETBEHAVIOUR, J

                    Case 65: Boss_1_Slow MODE_BULLETBEHAVIOUR, J
                    Case 66: Boss_2_Minion MODE_BULLETBEHAVIOUR, J
                    Case 67: Boss_3_Decagon MODE_BULLETBEHAVIOUR, J
                    Case 68: Boss_4_Absorber MODE_BULLETBEHAVIOUR, J
                    Case 69: Boss_5_Wave MODE_BULLETBEHAVIOUR, J
                    Case 70: Boss_6_Orbiter MODE_BULLETBEHAVIOUR, J
                End Select
                Enemies(J).Alive = Enemies(J).Health <> 0
                If Enemies(J).Alive = 0 Then KillEntity J
                Exit For
            End If
        Next J
        Select Case (BulletsDamage - 1) Mod 4
            Case 0: BulletsColour& = -1
            Case 1: BulletsColour& = _RGB32(0, 127, 255)
            Case 2: BulletsColour& = _RGB32(0, 191, 0)
            Case 3: BulletsColour& = _RGB32(255, 127, 0)
        End Select
        Circle (Bullets(I).Position.X - Camera.X, Bullets(I).Position.Y - Camera.Y), 2, BulletsColour&
        Circle (Bullets(I).Position.X - Camera.X, Bullets(I).Position.Y - Camera.Y), 3, BulletsColour&
    Next I
End Sub
Sub NewEnemyBullet (Source As Vec2, Angle As Single, Speed As Single) Static
    EnemyBullets(NewEnemyBulletID).Alive = -1
    EnemyBullets(NewEnemyBulletID).Position = Source
    NewVec2 EnemyBullets(NewEnemyBulletID).Velocity, Cos(Angle), Sin(Angle)
    Vec2Multiply EnemyBullets(NewEnemyBulletID).Velocity, Speed
    NewEnemyBulletID = NewEnemyBulletID + 1
End Sub
Sub DrawEnemyBullets Static
    Dim As _Unsigned Long I, J
    For I = 0 To UBound(EnemyBullets)
        If EnemyBullets(I).Alive = 0 Then _Continue
        If Vec2Dis(EnemyBullets(I).Position, Player.Position) >= 2048 Then EnemyBullets(I).Alive = 0: _Continue
        Vec2Add EnemyBullets(I).Position, EnemyBullets(I).Velocity
        If Vec2Dis(EnemyBullets(I).Position, Player.Position) < 20 Then
            EnemyBullets(I).Alive = 0
            Player.Health = Player.Health - 1
        End If
        For R = 1 To 3: Circle (EnemyBullets(I).Position.X - Camera.X, EnemyBullets(I).Position.Y - Camera.Y), R, -1: Next R
    Next I
End Sub

Sub NewMoney (Position As Vec2, Value As _Unsigned Integer) Static
    Points(NewMoneyID).Alive = -1
    Points(NewMoneyID).Position = Position
    Points(NewMoneyID).Value = Value
    NewMoneyID = NewMoneyID + 1
End Sub
Sub DrawMoney Static
    Dim As _Unsigned Long I
    For I = 0 To UBound(Points)
        If Points(I).Alive = 0 Then _Continue
        X = Points(I).Position.X - Camera.X
        Y = Points(I).Position.Y - Camera.Y
        DrawCoin X, Y, Points(I).Value, _RGB32(255, 191, 0)
        angle! = Vec2Angle(Points(I).Position, Player.Position)
        speed! = Max(1, 250 / Vec2Dis(Points(I).Position, Player.Position))
        Points(I).Position.X = Points(I).Position.X + speed! * Cos(angle!)
        Points(I).Position.Y = Points(I).Position.Y + speed! * Sin(angle!)
        distance! = Vec2Dis(Points(I).Position, Player.Position)
        If distance! < Player_Max_Radius Then
            PlayerMoney = PlayerMoney + Points(I).Value
            RadialCharge = RadialCharge - (RadialCharge < 100)
            LaserCharge = LaserCharge - (LaserCharge < 100)
            Points(I).Alive = 0
        End If
    Next I
End Sub
Sub DrawRadialAttack (PowerLevel As _Unsigned Integer) Static
    Static As _Unsigned Integer CurrentPowerLevel, FinalPowerLevel, OldFinalPowerLevel
    Dim As _Unsigned Long I
    If FinalPowerLevel < PowerLevel Then FinalPowerLevel = PowerLevel
    If PowerLevel = 0 Then
        S = IIF(FinalPowerLevel, 0, OldFinalPowerLevel - CurrentPowerLevel)
        E = IIF(FinalPowerLevel, CurrentPowerLevel, OldFinalPowerLevel - 1)
        For R = S To E
            Circle (Player.Position.X - Camera.X, Player.Position.Y - Camera.Y), Player_Max_Radius + R, _RGB32(0, 127, 255, 15)
        Next R
        CurrentPowerLevel = CurrentPowerLevel + MaxAbs((FinalPowerLevel - CurrentPowerLevel) / 4, Sgn(FinalPowerLevel - CurrentPowerLevel))
        If FinalPowerLevel > 0 Then
            For I = 0 To 1023
                If Vec2Dis(Player.Position, Enemies(I).Position) < Player_Max_Radius + CurrentPowerLevel And Enemies(I).Alive Then
                    Enemies(I).Health = Clamp(0, Enemies(I).Health - RadialWaveDamage, Enemies(I).MaxHealth)
                    Enemies(I).Alive = Enemies(I).Health <> 0
                    If Enemies(I).Alive = 0 Then KillEntity I
                End If
            Next I
        End If
    End If
    If CurrentPowerLevel = FinalPowerLevel Then
        OldFinalPowerLevel = FinalPowerLevel
        FinalPowerLevel = 0
    End If
End Sub
Sub DrawLaserAttack (PowerLevel As _Unsigned Integer) Static
    Static As _Unsigned Long CurrentPowerLevel, Length
    Dim As Vec2 LaserFinalPosition
    If PowerLevel = 0 And CurrentPowerLevel > 0 Then
        Angle! = Vec2Angle(MousePosition, Player.Position)
        Length = Length + 50
        NewVec2 LaserFinalPosition, Player.Position.X - Cos(Angle!) * Length, Player.Position.Y - Sin(Angle!) * Length
        Line (Player.Position.X - Camera.X, Player.Position.Y - Camera.Y)-(LaserFinalPosition.X - Camera.X, LaserFinalPosition.Y - Camera.Y), -1
        For I = 0 To 1023
            If InRange(Angle! - 0.05, Vec2Angle(Enemies(I).Position, Player.Position), Angle! + 0.05) And Vec2Dis(Enemies(I).Position, Player.Position) <= Length And Enemies(I).Alive Then
                Enemies(I).Health = Clamp(0, Enemies(I).Health - LaserDamage, Enemies(I).MaxHealth)
                Enemies(I).Alive = Enemies(I).Health <> 0
                If Enemies(I).Alive = 0 Then KillEntity I
            End If
        Next I
        CurrentPowerLevel = CurrentPowerLevel - 1
    Else
        Length = 0
        CurrentPowerLevel = PowerLevel
    End If
End Sub
Sub DrawCoin (X As Integer, Y As Integer, Value As Integer, Colour As Long)
    Dim normalized As Double
    Dim R As Integer, dY As Integer, halfWidth As Integer
    If Value < 1 Then Value = 1
    normalized = Log(Value) / 2
    If normalized > 1 Then normalized = 1
    R = 2 + (5 - 2) * normalized
    For dY = -R To R
        halfWidth = Sqr(R * R - dY * dY)
        Line (X - halfWidth, Y + dY)-(X + halfWidth, Y + dY), Colour
    Next
End Sub
'$Include:'lib\vector\vector.bm'
Function ceil# (x#)
    ceil# = Int(x#) + Sgn(x# - Int(x#))
End Function
Function RandomValuesInside! Static '(-0.5, 0.5)
    RandomValuesInside! = Rnd - 0.5
End Function
Function RandomValuesOutside! Static '(-0.6, -0.5) U (0.5, 0.6)
    If Rnd >= 0.5 Then RandomValuesOutside! = Rnd / 10 - 0.6 Else RandomValuesOutside! = 0.5 + Rnd / 10
End Function
Sub DesignSquare (X As Integer, Y As Integer, Rotate!, S1 As Integer, S2 As Integer, Colour As Long) Static
    DesignRegularPolygon 4, X, Y, Rotate!, 2 * S1, 2 * S2, Colour
End Sub
Sub DesignWaveCircle (X As Integer, Y As Integer, Rotate!, Frequency!, R1 As Integer, R2 As Integer, Colour As Long) Static
    For T! = 0 To 360: __T! = _D2R(T!) - Rotate!: __TC! = CosTable(T!): __TS! = SinTable(T!)
        L! = (1 + Cos(Frequency! * __T!) / 10)
        __X1 = X + R1 * L! * __TC!: __Y1 = Y + R1 * L! * __TS!: __X2 = X + R2 * L! * __TC!: __Y2 = Y + R2 * L! * __TS!
    Line (__X1, __Y1)-(__X2, __Y2), Colour: Next T!
End Sub
Sub DesignRegularPolygon (N As Integer, X As Integer, Y As Integer, Rotate As Single, R1 As Single, R2 As Single, Colour As _Unsigned Long)
    Dim Angle As Single, __Step As Single: __Step = _Pi(2) / N
    For I% = 0 To N - 1: Angle = Rotate + I% * __Step
        X1 = X + Cos(Angle) * R1: Y1 = Y + Sin(Angle) * R1
        X2 = X + Cos(Angle) * R2: Y2 = Y + Sin(Angle) * R2
        NextAngle = Rotate + ((I% + 1) Mod N) * __Step
        NX1 = X + Cos(NextAngle) * R1: NY1 = Y + Sin(NextAngle) * R1
        NX2 = X + Cos(NextAngle) * R2: NY2 = Y + Sin(NextAngle) * R2
        Line (X1, Y1)-(NX1, NY1), Colour: Line (X2, Y2)-(NX2, NY2), Colour: Line (X1, Y1)-(X2, Y2), Colour
Next I%: End Sub
Function MouseInBox (V1 As Vec2, V2 As Vec2)
    MouseInBox = InRange(V1.X, _MouseX, V2.X) And InRange(V1.Y, _MouseY, V2.Y)
End Function
Sub CenterPrint (X As Integer, Y As Integer, T$)
    __L~& = _PrintWidth(T$)
    _PrintString (X - _SHR(__L~&, 1), Y - 8), T$
End Sub
Sub RightPrint (Y As Integer, T$)
    __L~& = _PrintWidth(T$)
    _PrintString (_Width - __L~&, Y - 8), T$
End Sub
Sub WaitForMouseButton
    While _MouseInput Or _MouseButton(1) Or _MouseButton(2): Wend
End Sub
'$Include:'lib\inrange.bm'
'$Include:'lib\clamp.bm'
'$Include:'lib\modfloor.bm'
'$Include:'lib\iif.bm'
'$Include:'lib\min.bm'
'$Include:'lib\max.bm'
