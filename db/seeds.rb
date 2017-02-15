raise "These seeds assume you have page 1149380 in your database." unless Page.exists?(1149380)

page = Page.find(1149380)

ref = Referent.create(body: %Q{Govaerts R. (ed). For a full list of reviewers see: <a href="http://apps.kew.org/wcsp/compilersReviewers.do">http://apps.kew.org/wcsp/compilersReviewers.do</a> (2015). WCSP: World Checklist of Selected Plant Families (version Sep 2014). In: Species 2000 & ITIS Catalogue of Life, 26th August 2015 (Roskov Y., Abucay L., Orrell T., Nicolson D., Kunze T., Flann C., Bailly N., Kirk P., Bourgoin T., DeWalt R.E., Decock W., De Wever A., eds). Digital resource at <a href="http://www.catalogueoflife.org/col">www.catalogueoflife.org/col</a>. Species 2000: Naturalis, Leiden, the Netherlands. ISSN 2405-8858.})
page.referents << ref

Reference.create(parent: page.media.first, referent: ref)

ref = Referent.create(body: %Q{L. 1753. In: Sp. Pl. : 982})

Reference.create(parent: page.nodes.first, referent: ref)
page.referents << ref

ref = Referent.create(body: %Q{Marticorena C & R Rodríguez . 1995-2005. Flora de Chile. Vols 1, 2(1-3). Ed. Universidad de Concepción, Concepción. 351 pp., 99 pp., 93 pp., 128 pp. Matthei O. 1995. Manual de las malezas que crecen en Chile. Alfabeta Impresores. 545 p.})

Reference.create(parent: page.articles.first, referent: ref)
Reference.create(parent: page.media.last, referent: ref)
page.referents << ref
