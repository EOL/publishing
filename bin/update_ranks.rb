names = ["superdomain",
"taxonrank",
"superdivision",
"division",
"subdivision",
"subterclass",
"section",
"subsection",
"supercohort",
"infracohort",
"cohorte",
"subcohorte",
"subcohort",
"megacohort",
"cohort",
"clade",
"polyphyletic_group",
"paraphyletic_group",
"cultivar",
"grandorder",
"parvorder",
"mirorder",
"hyporder",
"epifamily",
"subtribe",
"supertribe",
"_group",
"genushybrid",
"speciesaggregate",
"species_group",
"forma_specialis",
"formspecialis",
"specieshybrid",
"variety",
"subvariety",
"nothovariety",
"subform",
"informal"]

Rank.where(name: names).update_all(treat_as: nil)