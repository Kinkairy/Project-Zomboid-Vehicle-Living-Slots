#!/usr/bin/env python3
"""Candidate validation rejects unreviewed changes; no game runtime is needed."""
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
if not (ROOT / "workshop").exists():
    ROOT = ROOT.parent / "mods/vehicle-living-slots"
validate = runpy.run_path(str(ROOT / "tools/check_runtime_manifest.py"))["validate"]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def fingerprint(files):
    return digest("".join(h + "  " + p + "\n" for p, h in sorted(files.items())).encode())


class CandidateValidation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / "workshop/Contents/mods"
        self.core = "VehicleLivingSlots/common/core.lua"
        self.camper = "VehicleLivingSlotsKI5Campers/common/config.lua"
        self.extra = "VehicleLivingSlotsKI5F700/common/config.lua"
        before = {self.core: digest(b"published"), self.camper: digest(b"campers")}
        after = {self.core: digest(b"approved"), self.camper: before[self.camper], self.extra: digest(b"f700")}
        self.published = {"files": before, "file_count": 2, "runtime_sha256": fingerprint(before)}
        self.addon = {"mod_id": "VehicleLivingSlotsKI5F700", "files": {self.extra: after[self.extra]},
            "runtime_sha256": fingerprint({self.extra: after[self.extra]})}
        self.write("release-3.9.json", self.published)
        self.write("release-f700-0.1.0.json", self.addon)
        self.candidate = {"schema": 1, "status": "source-candidate-not-deployed",
            "published_manifest": "release-3.9.json",
            "published_manifest_sha256": digest((self.root / "release-3.9.json").read_bytes()),
            "published_runtime_sha256": self.published["runtime_sha256"],
            "addon_manifest": "release-f700-0.1.0.json", "addon_runtime_sha256": self.addon["runtime_sha256"],
            "core_overrides": {self.core: {"before": before[self.core], "after": after[self.core]}},
            "file_count": 3, "runtime_sha256": fingerprint(after)}
        self.write("candidate-f700-0.1.0.json", self.candidate)
        for path, content in [(self.core, b"approved"), (self.camper, b"campers"), (self.extra, b"f700")]:
            file = self.folder / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(content)

    def write(self, name, value):
        (self.root / name).write_text(json.dumps(value))

    def rejected(self, message):
        with self.assertRaisesRegex(ValueError, message):
            validate(self.root)

    def test_reviewed_candidate_passes_and_exports_only_core(self):
        core, candidate = validate(self.root)
        self.assertEqual(set(core["files"]), {self.core, self.camper})
        self.assertEqual(candidate["file_count"], 3)
        self.assertEqual((self.root / "release-3.9.json").read_text(), json.dumps(self.published))

    def test_reviewed_camper_override_is_separate_from_core(self):
        content=b"new camper overlay"
        self.candidate["adapter_overrides"]={self.camper:{"before":self.published["files"][self.camper],"after":digest(content)}}
        (self.folder/self.camper).write_bytes(content)
        files={self.core:digest(b"approved"),self.camper:digest(content),self.extra:digest(b"f700")}
        self.candidate["runtime_sha256"]=fingerprint(files)
        self.write("candidate-f700-0.1.0.json",self.candidate)
        core,_=validate(self.root)
        self.assertEqual(core["files"][self.camper],digest(content))

    def test_adapter_override_cannot_escape_campers(self):
        self.candidate["adapter_overrides"]={self.core:{"before":digest(b"approved"),"after":digest(b"unreviewed")}}
        self.write("candidate-f700-0.1.0.json",self.candidate)
        self.rejected("outside the published adapter")

    def test_extra_file_is_rejected(self):
        (self.folder / "unexpected.lua").write_text("extra")
        self.rejected("Runtime mismatch.*unexpected.lua")

    def test_missing_file_is_rejected(self):
        (self.folder / self.extra).unlink()
        self.rejected("Runtime mismatch.*missing")

    def test_changed_file_is_rejected(self):
        (self.folder / self.core).write_text("unreviewed")
        self.rejected("Runtime mismatch.*changed")

    def test_stale_addon_fingerprint_is_rejected(self):
        self.addon["runtime_sha256"] = "0" * 64
        self.write("release-f700-0.1.0.json", self.addon)
        self.rejected("Addon fingerprint mismatch")

    def test_published_manifest_cannot_be_silently_replaced(self):
        self.published["files"][self.core] = digest(b"approved")
        self.write("release-3.9.json", self.published)
        self.rejected("Published manifest identity changed")

    def test_wrong_override_lineage_is_rejected(self):
        self.candidate["core_overrides"][self.core]["before"] = "0" * 64
        self.write("candidate-f700-0.1.0.json", self.candidate)
        self.rejected("Override baseline mismatch")

    def test_camper_override_is_not_a_core_ui_override(self):
        self.candidate["core_overrides"] = {self.camper: {"before": digest(b"campers"), "after": digest(b"changed")}}
        self.write("candidate-f700-0.1.0.json", self.candidate)
        self.rejected("Override outside the published core")

    def test_candidate_fingerprint_is_checked(self):
        self.candidate["runtime_sha256"] = "0" * 64
        self.write("candidate-f700-0.1.0.json", self.candidate)
        self.rejected("Candidate fingerprint mismatch")

    def test_file_count_is_checked(self):
        self.candidate["file_count"] = 4
        self.write("candidate-f700-0.1.0.json", self.candidate)
        self.rejected("Candidate file count mismatch")

    def test_symlink_cannot_hide_an_extra_payload(self):
        (self.folder / "linked").symlink_to(self.folder / self.extra)
        self.rejected("Runtime symlink")

    def test_path_escape_is_rejected(self):
        self.candidate["published_manifest"] = "../release-3.9.json"
        self.write("candidate-f700-0.1.0.json", self.candidate)
        self.rejected("Invalid manifest path")


if __name__ == "__main__":
    unittest.main()
