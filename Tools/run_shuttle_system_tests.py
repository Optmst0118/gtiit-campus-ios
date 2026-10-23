#!/usr/bin/env python3
"""Run pure production date/location/reminder policies on macOS without device permissions."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='gtiit-shuttle-policy-') as temp:
    path=Path(temp)
    # Only the iOS delegate shell is excluded. The production policy is unchanged.
    (path/'CampusProximity.swift').write_text((root/'GTIIT/Services/CampusLocationRecommendation.swift').read_text().split('@MainActor final class')[0])
    sources=['GTIIT/Core/Localization.swift','GTIIT/Models/ShuttleSchedule.swift','GTIIT/Services/ShuttleReminderPlan.swift','Tests/ShuttleSystemRegression.swift']
    subprocess.run(['xcrun','swiftc','-parse-as-library',*[str(root/s) for s in sources],str(path/'CampusProximity.swift'),'-o',str(path/'checks')],check=True)
    subprocess.run([str(path/'checks')],cwd=root,check=True)
