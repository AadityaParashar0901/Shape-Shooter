'Laser
'Bosses
'Upgrade Menu

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
    As Long Health, MaxHealth
    As _Byte MoveCooldown, ShootCooldown
End Type
Type Bullet
    As _Unsigned _Byte Alive
    As Vec2 Position, Velocity
    As _Unsigned Long Owner, Target
End Type
Type Money
    As _Unsigned _Byte Alive
    As Vec2 Position
    As _Unsigned Integer Value, HealValue
End Type

Dim Shared As Vec2 Camera

Dim Shared As Entity Player
NewVec2 Player.Position, _Width / 2, _Height / 2
Player.MaxSpeed = 2.5
Player.MaxHealth = 10
Player.Health = Player.MaxHealth

Dim Shared As _Unsigned Long RadialCharge: RadialCharge = 100

Dim Shared As Entity Enemies(0)

Dim Shared Bullets(1023) As Bullet, NewBulletID As _Unsigned _Bit * 10

Dim Shared Points(1023) As Money, NewMoneyID As _Unsigned _Bit * 10
Dim Shared As _Unsigned Long PlayerMoney: PlayerMoney = 10

Const ENEMY_CIRCLE = 1
Const ENEMY_SQUARE = 2
Const Player_Max_Radius = 20
Const CollisionResolutionDistance = 20
Const BulletSpeed = 20

Const RadialChargeRadius = 2.5

Dim As _Unsigned _Byte EnemySpawnCooldown

Dim Shared As Double Hardness

Dim Shared As Vec2 MousePosition

Do
    Cls , _RGB32(0, 0, 31)
    _Limit 60
    While _MouseInput
    Wend
    NewVec2 MousePosition, _MouseX, _MouseY: Vec2Add MousePosition, Camera
    DrawBackground
    DrawEnemies
    DrawBullets
    DrawMoney
    DrawRadialAttack 0
    DrawPlayer
    Print "Health:" + Str$(Player.Health) + "/" + _Trim$(Str$(Player.MaxHealth))
    Print "Money:" + Str$(PlayerMoney)
    Print "Radial Attack:" + Str$(Int(RadialCharge)); "%"
    Camera.X = Camera.X + (Player.Position.X - Camera.X - _Width / 2) / 16
    Camera.Y = Camera.Y + (Player.Position.Y - Camera.Y - _Height / 2) / 16
    _Display
    If EnemySpawnCooldown = 0 Then
        EnemySpawnCooldown = 30
        NewEnemy Int(Rnd * 2) + 1
    Else
        EnemySpawnCooldown = EnemySpawnCooldown - Sgn(EnemySpawnCooldown)
    End If
    KEY_W = _KeyDown(87) Or _KeyDown(119) Or _KeyDown(18432)
    KEY_S = _KeyDown(83) Or _KeyDown(115) Or _KeyDown(20480)
    KEY_A = _KeyDown(65) Or _KeyDown(97) Or _KeyDown(19200)
    KEY_D = _KeyDown(68) Or _KeyDown(100) Or _KeyDown(19712)
    Player.Position.X = Player.Position.X + Player.MaxSpeed * (KEY_A - KEY_D)
    Player.Position.Y = Player.Position.Y + Player.MaxSpeed * (KEY_W - KEY_S)
    If (_KeyDown(32) Or _MouseButton(1)) And Player.ShootCooldown = 0 And PlayerMoney >= 1 Then
        Player.ShootCooldown = 30 - Int(Hardness)
        NewBullet Player.Position, _Atan2(MousePosition.Y - Player.Position.Y, MousePosition.X - Player.Position.X)
        PlayerMoney = PlayerMoney - 1
    End If
    Player.ShootCooldown = Player.ShootCooldown - Sgn(Player.ShootCooldown)
    KeyHit = _KeyHit
    Select Case KeyHit
        Case 27: Exit Do
        Case 82, 114: 'Radial Attack
            If RadialCharge >= 25 Then DrawRadialAttack RadialCharge * RadialChargeRadius: RadialCharge = RadialCharge = RadialCharge - Min(RadialCharge, 100)
    End Select
    _KeyClear
    If HardnessIncreaseDelay = 0 Then
        HardnessIncreaseDelay = 15
        Hardness = Hardness + 0.01
    Else
        HardnessIncreaseDelay = HardnessIncreaseDelay - 1
    End If
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

Sub NewEnemy (__Type As _Unsigned _Byte) Static
    Dim As _Unsigned Long I
    I = UBound(Enemies) + 1
    ReDim _Preserve Enemies(1 To I) As Entity
    Enemies(I).Alive = -1
    Enemies(I).Type = __Type
    Enemies(I).Position.X = Player.Position.X + RandomValuesOutside * _Width
    Enemies(I).Position.Y = Player.Position.Y + RandomValuesOutside * _Height
    Enemies(I).MaxHealth = __Type
    Enemies(I).Health = Enemies(I).MaxHealth
    Enemies(I).MaxSpeed = 8 + Hardness
    Enemies(I).MoveCooldown = 0
    Enemies(I).ShootCooldown = 0
End Sub
Function RandomValuesOutside! Static '(-0.5, 0) U (1, 1.5)
    T! = Rnd - 0.5
    If T! >= 0 Then RandomValuesOutside! = T! + 1 Else RandomValuesOutside! = T!
End Function
Sub DrawPlayer Static
    For R = 16 To 20
        Circle (Player.Position.X - Camera.X, Player.Position.Y - Camera.Y), R, -1
    Next R
End Sub
Sub DrawEnemies Static
    Dim As _Unsigned Long I
    For I = 1 To UBound(Enemies)
        If Enemies(I).Alive = 0 Then _Continue
        Select Case Enemies(I).Type
            Case ENEMY_CIRCLE: For R = 10 To 15
                    Circle (Enemies(I).Position.X - Camera.X, Enemies(I).Position.Y - Camera.Y), R, _RGB32(0, 127, 255)
                Next R
                MinDis = Player_Max_Radius + 15
            Case ENEMY_SQUARE: For R = 10 To 12
                    Line (Enemies(I).Position.X - R - Camera.X, Enemies(I).Position.Y - R - Camera.Y)-(Enemies(I).Position.X + R - Camera.X, Enemies(I).Position.Y + R - Camera.Y), _RGB32(0, 191, 63), B
                Next R
                MinDis = Player_Max_Radius + 12
        End Select
        Enemies(I).Angle = _Atan2(Player.Position.Y - Enemies(I).Position.Y, Player.Position.X - Enemies(I).Position.X)
        distance! = Vec2Dis(Player.Position, Enemies(I).Position)
        If distance! > MinDis And Enemies(I).MoveCooldown < 0 Then
            Enemies(I).Position.X = Enemies(I).Position.X + Cos(Enemies(I).Angle)
            Enemies(I).Position.Y = Enemies(I).Position.Y + Sin(Enemies(I).Angle)
        End If
        If distance! < MinDis Then
            Select Case Enemies(I).Type
                Case ENEMY_CIRCLE, ENEMY_SQUARE
                    Player.Position.X = Player.Position.X + Cos(Enemies(I).Angle) * CollisionResolutionDistance
                    Player.Position.Y = Player.Position.Y + Sin(Enemies(I).Angle) * CollisionResolutionDistance
                    Enemies(I).Position.X = Enemies(I).Position.X - Cos(Enemies(I).Angle) * CollisionResolutionDistance
                    Enemies(I).Position.Y = Enemies(I).Position.Y - Sin(Enemies(I).Angle) * CollisionResolutionDistance
                    Player.Health = Player.Health - 1
            End Select
        End If
        Enemies(I).MoveCooldown = ClampCycle(-30, Enemies(I).MoveCooldown - 1, 120)
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
        For J = 1 To UBound(Enemies)
            If Vec2Dis(Bullets(I).Position, Enemies(J).Position) < 15 And Enemies(J).Alive Then
                Bullets(I).Alive = 0
                Enemies(J).Health = Clamp(0, Enemies(J).Health - 1, Enemies(J).MaxHealth)
                Enemies(J).Alive = Enemies(J).Health <> 0
                If Enemies(J).Alive = 0 Then NewMoney Enemies(J).Position, Enemies(J).MaxHealth
                Exit For
            End If
        Next J
        For R = 1 To 3: Circle (Bullets(I).Position.X - Camera.X, Bullets(I).Position.Y - Camera.Y), R, -1: Next R
    Next I
End Sub
Sub NewMoney (Position As Vec2, Value As _Unsigned Integer) Static
    Points(NewMoneyID).Alive = -1
    Points(NewMoneyID).Position = Position
    Points(NewMoneyID).Value = Value
    Points(NewMoneyID).HealValue = CInt(Rnd * 0.6)
    NewMoneyID = NewMoneyID + 1
End Sub
Sub DrawMoney Static
    Dim As _Unsigned Long I
    For I = 0 To UBound(Points)
        If Points(I).Alive = 0 Then _Continue
        For R = 1 To 3: Circle (Points(I).Position.X - Camera.X, Points(I).Position.Y - Camera.Y), R, _RGB32(255, 191, 0): Next R
        If Points(I).HealValue Then Circle (Points(I).Position.X - Camera.X, Points(I).Position.Y - Camera.Y), 4, _RGB32(255, 255, 0)
        angle! = Vec2Angle(Points(I).Position, Player.Position)
        speed! = Max(1, 250 / Vec2Dis(Points(I).Position, Player.Position))
        Points(I).Position.X = Points(I).Position.X + speed! * Cos(angle!)
        Points(I).Position.Y = Points(I).Position.Y + speed! * Sin(angle!)
        distance! = Vec2Dis(Points(I).Position, Player.Position)
        If distance! < Player_Max_Radius Then
            PlayerMoney = PlayerMoney + Points(I).Value
            RadialCharge = RadialCharge + Points(I).Value
            Player.Health = Player.Health + Points(I).HealValue
            Player.MaxHealth = Max(Player.Health, Player.MaxHealth)
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
    End If
    If CurrentPowerLevel = FinalPowerLevel And FinalPowerLevel > 0 Then
        For I = 1 To UBound(Enemies)
            If Vec2Dis(Player.Position, Enemies(I).Position) < Player_Max_Radius + FinalPowerLevel And Enemies(I).Alive Then
                Enemies(I).Health = Clamp(0, Enemies(I).Health - 5, Enemies(I).MaxHealth)
                Enemies(I).Alive = Enemies(I).Health <> 0
                If Enemies(I).Alive = 0 Then NewMoney Enemies(I).Position, Enemies(I).MaxHealth
            End If
        Next I
        OldFinalPowerLevel = FinalPowerLevel
        FinalPowerLevel = 0
    End If
End Sub
'$Include:'include\vector\vector.bm'
Function ceil# (x#)
    ceil# = Int(x#) + Sgn(x# - Int(x#))
End Function
Function CircleCollideCircle (A As Vec2, R1 As Single, B As Vec2, R2 As Single)
    CircleCollideCircle = (Vec2Dis(A, B) < R1 + R2)
End Function
Function CircleCollideSquare (A As Vec2, R As Single, P1 As Vec2, P2 As Vec2)
    CircleCollideSquare = (InRange(P1.X - R, A.X, P2.X + R) And InRange(P1.Y - R, A.Y, P2.Y + R))
End Function
'$Include:'include\inrange.bm'
'$Include:'include\clamp.bm'
'$Include:'include\modfloor.bm'
'$Include:'include\iif.bm'
'$Include:'include\min.bm'
'$Include:'include\max.bm'
