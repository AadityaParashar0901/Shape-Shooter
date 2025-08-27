'$Dynamic
'$Include:'include\vector\vector.bi'
Randomize Timer
Screen _NewImage(640, 640, 32)
_Title "Shape Shooter"
Color -1, 0

Type Entity
    As _Unsigned _Byte Alive, Type
    As Vec2 Position
    As Single Angle, MaxSpeed
    As Single Health, MaxHealth
    As Integer MoneyValue
    As _Byte MoveCooldown, ShootCooldown

    As Single StyleAngle
End Type
Type Bullet
    As _Unsigned _Byte Alive
    As Vec2 Position, Velocity
    As _Unsigned Long Target
End Type
Type Money
    As _Unsigned _Byte Alive
    As Vec2 Position
    As _Unsigned Integer Value, HealValue
End Type

Dim Shared As Vec2 Camera

Dim Shared As Single CosTable(0 To 360), SinTable(0 To 360)
For T! = 0 To 360
    CosTable(T!) = Cos(_D2R(T!))
    SinTable(T!) = Sin(_D2R(T!))
Next T!

Dim Shared As Entity Player
NewVec2 Player.Position, _Width / 2, _Height / 2
Player.MaxSpeed = 2.5
Player.MaxHealth = 10
Player.Health = Player.MaxHealth
Dim Shared PlayerMultiShot, PlayerShootCooldown
PlayerMultiShot = 1
PlayerShootCooldown = 30

Dim Shared BigFont&, Font&
Font& = _LoadFont("consola.ttf", 16, "MONOSPACE")
BigFont& = _LoadFont("consola.ttf", 32, "MONOSPACE")
_Font Font&

Const D2R_90 = _D2R(90)

Dim Shared As _Unsigned Long RadialCharge, LaserCharge

Dim Shared Enemies(1023) As Entity, NewEnemyID As _Unsigned _Bit * 10

Dim Shared Bullets(1023) As Bullet, NewBulletID As _Unsigned _Bit * 10
Dim Shared EnemyBullets(1023) As Bullet, NewEnemyBulletID As _Unsigned _Bit * 10

Dim Shared Points(1023) As Money, NewMoneyID As _Unsigned _Bit * 10
Dim Shared As _Unsigned Long PlayerMoney

Const ENEMY_CIRCLE = 1
Const ENEMY_SQUARE = 2
Const ENEMY_BOSS = 65

Const Player_Max_Radius = 20
Const CollisionResolutionDistance = 20
Const BulletSpeed = 20

Const RadialChargeRadius = 2.5
Const LaserChargeRadius = 0.3

Dim As _Unsigned _Byte EnemySpawnCooldown
Dim As _Unsigned Integer BossSpawnCooldown: BossSpawnCooldown = 0

Dim Shared As Double Hardness

Dim Shared As Vec2 MousePosition

Dim Shared As _Unsigned Long TimeCounter

Dim Shared As _Unsigned Long Score

Do
    Cls , _RGB32(0, 0, 31)
    _Limit 60
    While _MouseInput
    Wend
    NewVec2 MousePosition, _MouseX, _MouseY: Vec2Add MousePosition, Camera

    DrawBackground
    DrawEnemies
    DrawBullets: DrawEnemyBullets
    DrawMoney
    DrawRadialAttack 0: DrawLaserAttack 0
    DrawPlayer
    RightPrint 8, "Health:" + Str$(Player.Health) + "/" + _Trim$(Str$(Player.MaxHealth))
    _Font BigFont&: CenterPrint _Width / 2, 16, Score$: Print "Money:" + Str$(PlayerMoney): _Font Font&
    _PrintString (0, 32), "Radial Attack:" + Str$(Int(RadialCharge)) + "%"
    _PrintString (0, 48), "Laser Attack:" + Str$(Int(LaserCharge)) + "%"
    Score$ = "Score:" + Str$(Score)
    Camera.X = Camera.X + (Player.Position.X - Camera.X - _Width / 2) / 16
    Camera.Y = Camera.Y + (Player.Position.Y - Camera.Y - _Height / 2) / 16
    _Display

    If EnemySpawnCooldown = 0 Then
        EnemySpawnCooldown = Max(10, 30 - Hardness)
        NewEnemy Int(Rnd * Min(8, 2 + CInt(Hardness))) + 1
    Else
        EnemySpawnCooldown = EnemySpawnCooldown - Sgn(EnemySpawnCooldown)
    End If
    If BossSpawnCooldown = 0 Then
        BossSpawnCooldown = Max(180, 3600 - 10 * Hardness)
        NewBossEnemy Int(Rnd * Min(1, ceil(Hardness))) + 1
    Else
        BossSpawnCooldown = BossSpawnCooldown - Sgn(BossSpawnCooldown)
    End If

    KEY_W = _KeyDown(87) Or _KeyDown(119) Or _KeyDown(18432)
    KEY_S = _KeyDown(83) Or _KeyDown(115) Or _KeyDown(20480)
    KEY_A = _KeyDown(65) Or _KeyDown(97) Or _KeyDown(19200)
    KEY_D = _KeyDown(68) Or _KeyDown(100) Or _KeyDown(19712)
    Player.Position.X = Player.Position.X + Player.MaxSpeed * (KEY_A - KEY_D)
    Player.Position.Y = Player.Position.Y + Player.MaxSpeed * (KEY_W - KEY_S)
    If (_KeyDown(32) Or _MouseButton(1)) And Player.ShootCooldown = 0 Then
        Player.ShootCooldown = PlayerShootCooldown
        AngleDifference! = -0.05 / PlayerMultiShot
        Dim As Vec2 NewBulletPosition
        Angle! = Vec2Angle(Player.Position, MousePosition)
        For I = 1 To PlayerMultiShot
            NewVec2 NewBulletPosition, Player.Position.X + 5 * Cos(Angle! + D2R_90), Player.Position.Y + 5 * Sin(Angle! + D2R_90)
            NewBullet Player.Position, Angle! + AngleDifference!
            AngleDifference! = AngleDifference! + 0.1 / PlayerMultiShot
        Next I
    End If
    Player.ShootCooldown = Player.ShootCooldown - Sgn(Player.ShootCooldown)
    KeyHit = _KeyHit
    Select Case KeyHit
        Case 27: DrawMenu
        Case 82, 114: 'Radial Attack
            If RadialCharge >= 25 Then DrawRadialAttack RadialCharge * RadialChargeRadius: RadialCharge = 0
        Case 67, 99: 'Laser Attack
            If LaserCharge >= 25 Then DrawLaserAttack LaserCharge * LaserChargeRadius: LaserCharge = 0
    End Select
    _KeyClear
    If Hardness < 10 Then
        If HardnessIncreaseDelay = 0 Then
            HardnessIncreaseDelay = 60
            Hardness = Hardness + 0.01
        Else
            HardnessIncreaseDelay = HardnessIncreaseDelay - 1
        End If
    End If
    TimeCounter = ClampCycle(0, TimeCounter + 1, 59)
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
    Type Rectangle
        As Vec2 P1, P2
    End Type
    Static As _Unsigned Long Cost_MaxSpeed, Cost_MultiShot, Cost_FireSpeed
    Static As _Unsigned Integer Level_MaxSpeed, Level_MultiShot, Level_FireSpeed
    If Cost_MaxSpeed = 0 Then Cost_MaxSpeed = 10
    If Cost_MultiShot = 0 Then Cost_MultiShot = 100
    If Cost_FireSpeed = 0 Then Cost_FireSpeed = 25
    Dim As Rectangle Box1, Box2, Box3
    NewVec2 Box1.P1, 0.25 * _Width - 64, 0.5 * _Height - 128: NewVec2 Box1.P2, 0.25 * _Width + 64, 0.5 * _Height + 128
    NewVec2 Box2.P1, 0.50 * _Width - 64, 0.5 * _Height - 128: NewVec2 Box2.P2, 0.50 * _Width + 64, 0.5 * _Height + 128
    NewVec2 Box3.P1, 0.75 * _Width - 64, 0.5 * _Height - 128: NewVec2 Box3.P2, 0.75 * _Width + 64, 0.5 * _Height + 128
    Do
        Cls , _RGB32(0, 0, 31)
        _Limit 60
        While _MouseInput: Wend
        If MouseInBox(Box1.P1, Box1.P2) Then
            S1 = S1 + Sgn(5 - S1)
            If _MouseButton(1) And PlayerMoney >= Cost_MaxSpeed Then
                PlayerMoney = PlayerMoney - Cost_MaxSpeed
                Player.MaxSpeed = Player.MaxSpeed + 0.1
                Cost_MaxSpeed = Cost_MaxSpeed + 10
                Level_MaxSpeed = Level_MaxSpeed + 1
                WaitForMouseButton
            End If
        Else S1 = S1 - Sgn(S1)
        End If
        If MouseInBox(Box2.P1, Box2.P2) Then
            S2 = S2 + Sgn(5 - S2)
            If _MouseButton(1) And PlayerMoney >= Cost_MultiShot Then
                PlayerMoney = PlayerMoney - Cost_MultiShot
                PlayerMultiShot = PlayerMultiShot + 1
                Cost_MultiShot = Cost_MultiShot + 100
                Level_MultiShot = Level_MultiShot + 1
                WaitForMouseButton
            End If
        Else S2 = S2 - Sgn(S2)
        End If
        If MouseInBox(Box3.P1, Box3.P2) Then
            S3 = S3 + Sgn(5 - S3)
            If _MouseButton(1) And PlayerMoney >= Cost_FireSpeed Then
                PlayerMoney = PlayerMoney - Cost_FireSpeed
                Level_FireSpeed = Level_FireSpeed + 1
                PlayerShootCooldown = 30 / Level_FireSpeed
                Cost_FireSpeed = Cost_FireSpeed * 2
                WaitForMouseButton
            End If
        Else S3 = S3 - Sgn(S3)
        End If
        _Font BigFont&: CenterPrint _Width / 2, 48, "Money:" + Str$(PlayerMoney): _Font Font&
        Line (Box1.P1.X - S1, Box1.P1.Y - S1)-(Box1.P2.X + S1, Box1.P2.Y + S1), IIF(PlayerMoney >= Cost_MaxSpeed, -1, _RGB32(255, 0, 0)), B
        CenterPrint 0.25 * _Width, 0.4 * _Height - 16, "Speed"
        CenterPrint 0.25 * _Width, 0.5 * _Height - 16, "Level" + Str$(Level_MaxSpeed + 1)
        CenterPrint 0.25 * _Width, 0.5 * _Height + 32, _Trim$(Str$(Cost_MaxSpeed))
        Line (Box2.P1.X - S2, Box2.P1.Y - S2)-(Box2.P2.X + S2, Box2.P2.Y + S2), IIF(PlayerMoney >= Cost_MultiShot, -1, _RGB32(255, 0, 0)), B
        CenterPrint 0.50 * _Width, 0.4 * _Height - 16, "MultiShot"
        CenterPrint 0.50 * _Width, 0.5 * _Height - 16, "Level" + Str$(Level_MultiShot + 1)
        CenterPrint 0.50 * _Width, 0.5 * _Height + 32, _Trim$(Str$(Cost_MultiShot))
        Line (Box3.P1.X - S3, Box3.P1.Y - S3)-(Box3.P2.X + S3, Box3.P2.Y + S3), IIF(PlayerMoney >= Cost_FireSpeed, -1, _RGB32(255, 0, 0)), B
        CenterPrint 0.75 * _Width, 0.4 * _Height - 16, "Fire"
        CenterPrint 0.75 * _Width, 0.5 * _Height - 16, "Level" + Str$(Level_FireSpeed + 1)
        CenterPrint 0.75 * _Width, 0.5 * _Height + 32, _Trim$(Str$(Cost_FireSpeed))
        _Display
    Loop Until _KeyHit = 27
End Sub

Sub NewEnemy (__Type As _Unsigned _Byte) Static
    Enemies(NewEnemyID).Alive = -1
    Enemies(NewEnemyID).Type = __Type
    Enemies(NewEnemyID).Position.X = Player.Position.X + RandomValuesOutside * _Width
    Enemies(NewEnemyID).Position.Y = Player.Position.Y + RandomValuesOutside * _Height
    Enemies(NewEnemyID).MaxHealth = __Type
    Enemies(NewEnemyID).Health = Enemies(NewEnemyID).MaxHealth
    Enemies(NewEnemyID).MaxSpeed = 8 + Hardness - 2 * (__Type = 1)
    Enemies(NewEnemyID).MoveCooldown = 0
    Enemies(NewEnemyID).ShootCooldown = 0
    Enemies(NewEnemyID).MoneyValue = Enemies(NewEnemyID).MaxHealth
    NewEnemyID = NewEnemyID + 1
End Sub
Sub NewBossEnemy (__Type As _Unsigned _Byte) Static
    Enemies(NewEnemyID).Alive = -1
    Enemies(NewEnemyID).Type = Clamp(65, __Type + 64, 65)
    Enemies(NewEnemyID).Position.X = Player.Position.X + RandomValuesOutside * _Width
    Enemies(NewEnemyID).Position.Y = Player.Position.Y + RandomValuesOutside * _Height
    Enemies(NewEnemyID).MaxHealth = 10 * __Type
    Enemies(NewEnemyID).Health = Enemies(NewEnemyID).MaxHealth
    Enemies(NewEnemyID).MaxSpeed = 2 + Hardness - 2 * (__Type = 1)
    Enemies(NewEnemyID).MoveCooldown = 0
    Enemies(NewEnemyID).ShootCooldown = 0
    Enemies(NewEnemyID).MoneyValue = Enemies(NewEnemyID).MaxHealth
    NewEnemyID = NewEnemyID + 1
End Sub

Sub DrawPlayer Static
    For R = 16 To 20
        Circle (Player.Position.X - Camera.X, Player.Position.Y - Camera.Y), R, -1
    Next R
End Sub
Sub DrawEnemies Static
    Dim As _Unsigned Long I
    For I = 0 To 1023
        If Enemies(I).Alive = 0 Then _Continue
        X = Enemies(I).Position.X - Camera.X
        Y = Enemies(I).Position.Y - Camera.Y
        Select EveryCase Enemies(I).Type
            Case ENEMY_CIRCLE: For R = 10 To 15
                    Circle (X, Y), R, _RGB32(0, 127, 255)
                Next R
            Case ENEMY_SQUARE
                DesignSquare X, Y, Enemies(I).StyleAngle, 10, 12, _RGB32(0, 191, 63)
            Case 3
                DesignRegularPolygon 3, X, Y, Enemies(I).StyleAngle, 14, 15, _RGB32(255, 0, 255) 'Triangle
            Case 5
                DesignRegularPolygon 5, X, Y, Enemies(I).StyleAngle, 14, 15, _RGB32(255, 0, 255) 'Pentagon
            Case 6
                DesignRegularPolygon 6, X, Y, Enemies(I).StyleAngle, 14, 15, _RGB32(255, 0, 255) 'Hexagon
            Case 8
                DesignRegularPolygon 8, X, Y, Enemies(I).StyleAngle, 14, 15, _RGB32(255, 0, 255) 'Octagon
            Case 4
                DesignRoseCurves X, Y, Enemies(I).StyleAngle, 13, 15, -1
            Case 7
                DesignHypocycloids X, Y, Enemies(I).StyleAngle, 10, 12, _RGB32(31, 127, 0)
            Case 65
                Dim As Vec2 CurrentLinePosition
                DesignCircle Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y, Enemies(I).StyleAngle, 10, 42 + 8 * Cos(Enemies(I).StyleAngle), 50 + 8 * Cos(Enemies(I).StyleAngle), _RGB32(191, 0, 95)
                EnemyMove = -1
                If Enemies(I).ShootCooldown = 0 Then
                    For J = 1 To 6
                        NewEnemyBullet Enemies(I).Position, Enemies(I).StyleAngle + J * _Pi / 3, 1
                    Next J
                    Enemies(I).ShootCooldown = 60
                End If
            Case ENEMY_CIRCLE, ENEMY_SQUARE, 3, 4, 5, 6, 7, 8
                MinDis = Player_Max_Radius + 15
                EnemyMove = -1
        End Select
        Enemies(I).Angle = _Atan2(Player.Position.Y - Enemies(I).Position.Y, Player.Position.X - Enemies(I).Position.X)
        distance! = Vec2Dis(Player.Position, Enemies(I).Position)
        If distance! > MinDis And Enemies(I).MoveCooldown < 0 And EnemyMove Then
            Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
            Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
        End If
        If distance! < MinDis Then
            Select Case Enemies(I).Type
                Case Is <= 64
                    Player.Position.X = Player.Position.X + Cos(Enemies(I).Angle) * CollisionResolutionDistance
                    Player.Position.Y = Player.Position.Y + Sin(Enemies(I).Angle) * CollisionResolutionDistance
                    Enemies(I).Position.X = Enemies(I).Position.X - Cos(Enemies(I).Angle) * CollisionResolutionDistance
                    Enemies(I).Position.Y = Enemies(I).Position.Y - Sin(Enemies(I).Angle) * CollisionResolutionDistance
                    Player.Health = Player.Health - 1
            End Select
        End If
        Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 120)
        Enemies(I).ShootCooldown = Enemies(I).ShootCooldown - Sgn(Enemies(I).ShootCooldown)
        Enemies(I).StyleAngle = Enemies(I).StyleAngle + 0.01
    Next I
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
        If Vec2Dis(Bullets(I).Position, Player.Position) >= 512 Then Bullets(I).Alive = 0: _Continue
        For J = 0 To 1023
            If Enemies(J).Alive And Vec2Dis(Bullets(I).Position, Enemies(J).Position) < 15 Then
                Bullets(I).Alive = 0
                Enemies(J).Health = Clamp(0, Enemies(J).Health - 1, Enemies(J).MaxHealth)
                Enemies(J).Alive = Enemies(J).Health <> 0
                If Enemies(J).Alive = 0 Then NewMoney Enemies(J).Position, Enemies(J).MoneyValue
                Exit For
            End If
        Next J
        For R = 1 To 3: Circle (Bullets(I).Position.X - Camera.X, Bullets(I).Position.Y - Camera.Y), R, -1: Next R
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
        If Vec2Dis(EnemyBullets(I).Position, Player.Position) < 15 Then
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
    Points(NewMoneyID).HealValue = CInt(Rnd * 0.6)
    Score = Score + 5 * Value
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
            Player.Health = Player.Health + Points(I).HealValue
            Player.Health = Min(Player.Health, Player.MaxHealth)
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
                    Enemies(I).Health = Clamp(0, Enemies(I).Health - 5, Enemies(I).MaxHealth)
                    Enemies(I).Alive = Enemies(I).Health <> 0
                    If Enemies(I).Alive = 0 Then NewMoney Enemies(I).Position, Enemies(I).MoneyValue
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
                Enemies(I).Health = Clamp(0, Enemies(I).Health - 0.5, Enemies(I).MaxHealth)
                Enemies(I).Alive = Enemies(I).Health <> 0
                If Enemies(I).Alive = 0 Then NewMoney Enemies(I).Position, Enemies(I).MoneyValue
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
    R = 2 + (10 - 2) * normalized
    For dY = -R To R
        halfWidth = Sqr(R * R - dY * dY)
        Line (X - halfWidth, Y + dY)-(X + halfWidth, Y + dY), Colour
    Next
End Sub
'$Include:'include\vector\vector.bm'
Function ceil# (x#)
    ceil# = Int(x#) + Sgn(x# - Int(x#))
End Function
Function RandomValuesOutside! Static '(-0.5, 0) U (1, 1.5)
    If Rnd >= 0.5 Then RandomValuesOutside! = Rnd / 2 - 1 Else RandomValuesOutside! = 1 + Rnd / 2
End Function
Sub DesignSquare (X As Integer, Y As Integer, Rotate!, S1 As Integer, S2 As Integer, Colour As Long) Static
    For T! = 0 To 360: __T! = _D2R(T!): __TC! = CosTable(T!): __TS! = SinTable(T!)
        L! = 2 / (Abs(Cos(__T!)) + Abs(Sin(__T!)))
        __X1 = X + S1 * L! * __TC!: __Y1 = Y + S1 * L! * __TS!: __X2 = X + S2 * L! * __TC!: __Y2 = Y + S2 * L! * __TS!
    Line (__X1, __Y1)-(__X2, __Y2), Colour: Next T!
End Sub
Sub DesignCircle (X As Integer, Y As Integer, Rotate!, Frequency!, R1 As Integer, R2 As Integer, Colour As Long) Static
    For T! = 0 To 360: __T! = _D2R(T!) - Rotate!: __TC! = CosTable(T!): __TS! = SinTable(T!)
        L! = (1 + Cos(Frequency! * __T!) / 10)
        __X1 = X + R1 * L! * __TC!: __Y1 = Y + R1 * L! * __TS!: __X2 = X + R2 * L! * __TC!: __Y2 = Y + R2 * L! * __TS!
    Line (__X1, __Y1)-(__X2, __Y2), Colour: Next T!
End Sub
Sub DesignRoseCurves (X As Integer, Y As Integer, Rotate!, R1 As Integer, R2 As Integer, Colour As Long) Static
    For T! = 0 To 360: __T! = _D2R(T!) - Rotate!: __TC! = CosTable(T!): __TS! = SinTable(T!)
        L! = Cos(4 * __T!)
        __X1 = X + R1 * L! * __TC!: __Y1 = Y + R1 * L! * __TS!: __X2 = X + R2 * L! * __TC!: __Y2 = Y + R2 * L! * __TS!
    Line (__X1, __Y1)-(__X2, __Y2), Colour: Next T!
End Sub
Sub DesignHypocycloids (X As Integer, Y As Integer, Rotate!, R1 As Integer, R2 As Integer, Colour As Long) Static
    For T! = 0 To 360: __T! = _D2R(T!) - Rotate!: __TC! = CosTable(T!): __TS! = SinTable(T!)
        L! = 1 - Cos(8 * __T!)
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
'$Include:'include\inrange.bm'
'$Include:'include\clamp.bm'
'$Include:'include\modfloor.bm'
'$Include:'include\iif.bm'
'$Include:'include\min.bm'
'$Include:'include\max.bm'
