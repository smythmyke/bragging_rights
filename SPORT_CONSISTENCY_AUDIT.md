# Sport Consistency Audit Report

## Overview
This audit examines consistency across sports in betting and pool selection workflows.

## 🏈 BETTING FLOW CONSISTENCY

### ✅ **Consistent Patterns**

#### 1. **Sport Detection Logic**
All sport detection uses consistent patterns:
```dart
final sportUpper = widget.sport.toUpperCase().trim();
```

#### 2. **Tab Structure**
- **Team Sports** (NFL, NBA, NHL, MLB): 5 tabs (Moneyline, Spread, Totals, Props, Live)
- **Combat Sports** (MMA, UFC, Boxing): 3 tabs (Moneyline, Method of Victory, Rounds)
- **Tennis**: 3 tabs (Match, Sets, Games)

#### 3. **API Integration**
All sports use consistent `OddsApiService.getEventOdds()` with:
- `includeProps: true` ✅ (Fixed)
- Sport-specific prop markets in switch statement ✅
- Consistent error handling ✅

### ⚠️ **Inconsistencies Found**

#### 1. **MMA Promotion Handling**
**Location**: `pool_selection_screen.dart` lines 1092-1096, 1143-1146, 1270-1273

**Issue**: Hardcoded combat sport detection:
```dart
final isCombatSport = widget.sport == 'UFC' || 
                     widget.sport == 'BOXING' ||
                     widget.sport == 'BELLATOR' ||
                     widget.sport == 'PFL';
```

**Problem**: 
- Doesn't include 'MMA', 'INVICTA', 'ONE'
- Uses exact string matching instead of `.contains()` or normalized logic
- Repeated 3 times in the same file

#### 2. **Route Handling Inconsistency**
**Location**: `main.dart` fight-card-grid route vs bet-selection route

**Combat Sports Flow**:
```
Game Selection → Pool Selection → Fight Card Grid → (Individual Fight Details)
```

**Other Sports Flow**:
```
Game Selection → Pool Selection → Bet Selection → (Props/Spread/etc tabs)
```

**Issue**: Different navigation patterns for different sports

## 🎯 POOL SELECTION CONSISTENCY

### ✅ **Consistent Patterns**

#### 1. **Pool Creation**
All sports use same `PoolService.createPool()` parameters:
- `gameId`, `gameTitle`, `sport`, `type`, `name`, `buyIn`

#### 2. **Data Flow**
Consistent argument passing:
```dart
arguments: {
  'gameId': gameId,
  'gameTitle': widget.gameTitle,
  'sport': widget.sport,
  'poolName': poolName,
  'poolId': poolId,
}
```

### ⚠️ **Inconsistencies Found**

#### 1. **Sport Recognition Gaps**
Combat sport detection doesn't include all MMA promotions that are supported in `OddsApiService`:

**Supported in OddsApiService**:
- mma, ufc, bellator, pfl, invicta, one

**Detected in PoolSelection**:
- UFC, BOXING, BELLATOR, PFL

**Missing**: MMA, INVICTA, ONE

## 🎨 UI/UX VARIATIONS

### ✅ **Consistent Elements**

#### 1. **Tab Styling**
All sports use consistent `TabBar` styling with `isScrollable: true`

#### 2. **Bet Selection UI**
Consistent bet card styling, odds display format, selection indicators

### ⚠️ **Inconsistencies Found**

#### 1. **Live Betting Messages**
**Location**: `bet_selection_screen.dart` line 1474-1476

```dart
widget.sport.toUpperCase() == 'MMA' || widget.sport.toUpperCase() == 'BOXING'
    ? 'Live Betting Available When Fight Starts'
    : 'Live Betting Available When Game Starts'
```

**Issue**: Only checks for 'MMA' and 'BOXING', missing other combat sports

#### 2. **Props Tab Availability**
Props tab only available for team sports, not combat sports. This might be intentional but should be documented.

## 🔄 DATA FLOW CONSISTENCY

### ✅ **Consistent Patterns**

#### 1. **Argument Passing**
All screens receive consistent data structure with gameId, gameTitle, sport, etc.

#### 2. **Service Integration**
All sports use same services (`OddsApiService`, `PoolService`, `BetService`)

### ⚠️ **Issues Found**

#### 1. **Fallback Logic**
**Location**: `bet_selection_screen.dart` lines 247, 256

```dart
if (widget.sport.toUpperCase().contains('NFL') || widget.sport.toUpperCase().contains('FOOTBALL'))
```

Only NFL gets fallback mock data. Other sports have no fallback.

## 📊 SUMMARY OF INCONSISTENCIES

### **Critical Issues** 🚨
1. **MMA Promotion Detection Gap** - Missing INVICTA, ONE, general 'MMA'
2. **Inconsistent Combat Sport Recognition** - Hardcoded vs. flexible detection

### **Minor Issues** ⚠️
1. **Live Betting Message** - Missing some combat sports
2. **Fallback Logic** - Only NFL has mock data fallback
3. **Repeated Code** - Combat sport detection duplicated 3 times

### **Architectural Differences** ℹ️
1. **Different Navigation Flows** - Combat sports vs traditional sports (might be intentional)
2. **Props Tab Exclusion** - Combat sports don't have props tab (might be intentional)

## 🔧 RECOMMENDATIONS

### **High Priority**
1. Create centralized sport detection utility
2. Expand combat sport recognition to include all supported promotions
3. Consolidate repeated sport detection logic

### **Medium Priority**
1. Add fallback logic for all sports, not just NFL
2. Standardize live betting messages
3. Document intentional architectural differences

### **Low Priority**
1. Consider unified navigation flow if business requirements allow
2. Evaluate if combat sports should have props tabs