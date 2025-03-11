---
name: Release BBS-Exporter
about: Track release steps
title: New Release
labels: 
assignees:
---

## Steps

- [ ] Update Dockerfile labels
- [ ] Update `BbsExporter::VERSION`
- [ ] Update Gemfile.lock
	- example: [pr for 1.5.2](https://github.com/github/bbs-exporter/pull/732/files)
- [ ] Diff [your version](https://github.com/github/bbs-exporter/issues/532#issuecomment-547537436)
- [ ] Publish draft [release](https://github.com/github/bbs-exporter/issues/706#issue-887613769)
- [ ] Upload to Google drive (https://drive.google.com/drive/u/0/folders/1Oizu_sJ_snssOFgmyozyEn-w9YFVezhJ)