﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using WaveEngine.Components.Graphics3D;
using WaveEngine.Framework;
using WaveEngine_MRTK_Demo.Effects;
using WaveEngine_MRTK_Demo.Emulation;

namespace WaveEngine_MRTK_Demo.Behaviors
{
    class CursorPosShaderUpdater : Behavior
    {
        HoloGraphic materialDecorator;
        CursorManager cursorManager;

        [BindComponent(isRequired: true, source: BindComponentSource.Owner)]
        protected MaterialComponent materialComponent;

        protected override void Start()
        {
            cursorManager = Owner.Scene.Managers.FindManager<CursorManager>();
            materialDecorator = new HoloGraphic(materialComponent.Material);
        }

        protected override void Update(TimeSpan gameTime)
        {
            materialDecorator.Parameters_FingerPosLeft = cursorManager.Cursors[0].transform.Position;
            materialDecorator.Parameters_FingerPosRight = cursorManager.Cursors[1].transform.Position;
        }
    }
}
