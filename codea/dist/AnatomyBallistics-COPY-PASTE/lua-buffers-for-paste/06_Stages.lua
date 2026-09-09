-- Stages.lua
-- Range progression: 40→15 ft by 5 ft, then drywall+wood house-wall stage.

Stages = {}

function Stages.new(loadKey)
    local st = {
        index = 1,
        loadKey = loadKey or TwentyTwo.DEFAULT_LOAD,
        shotsThisStage = 0,
        autoAdvance = true,
    }
    st.snap = TwentyTwo.stageSnapshot(st.index, st.loadKey)
    return st
end

function Stages.refresh(st)
    st.snap = TwentyTwo.stageSnapshot(st.index, st.loadKey)
    return st.snap
end

function Stages.advance(st)
    local nextI = TwentyTwo.nextStageIndex(st.index)
    if nextI == st.index then
        return false, st.snap
    end
    st.index = nextI
    st.shotsThisStage = 0
    Stages.refresh(st)
    return true, st.snap
end

function Stages.reset(st)
    st.index = 1
    st.shotsThisStage = 0
    Stages.refresh(st)
    return st.snap
end

function Stages.onShotFired(st)
    st.shotsThisStage = (st.shotsThisStage or 0) + 1
end

-- After impact cinematic, optionally step closer / into wall stage.
function Stages.maybeAdvanceAfterImpact(st)
    if not st.autoAdvance then
        return false, st.snap
    end
    return Stages.advance(st)
end

function Stages.hudText(st)
    local s = st.snap
    if s.throughWall then
        return string.format(
            "STAGE %d/%d  %s\n.22 LR %dgr  impact %.0f fps · %.0f ft·lbf  (pre-wall %.0f fps)\nBarrier Δv −%.0f fps (2×½″ drywall + pine stud)",
            s.index, s.maxIndex, s.label,
            s.grain, s.impactFps, s.impactFtlb, s.preWallFps, s.wallDeltaFps
        )
    end
    return string.format(
        "STAGE %d/%d  %s\n.22 LR %dgr  impact %.0f fps · %.0f ft·lbf · %.0f J",
        s.index, s.maxIndex, s.label,
        s.grain, s.impactFps, s.impactFtlb, s.impactJoules
    )
end
