import Nimble
import XCTest
import LASwift
import NaturalLanguage
@testable import Clustering
import Accelerate

// swiftlint:disable:next type_body_length
class ClusteringTests: XCTestCase {

    /// Test that initialization of the clustering module is done with all parameters as expected
    func testInitialization() throws {
        let cluster = Cluster()
        expect(cluster.candidate) == 2
        expect(cluster.laplacianCandidate) == .randomWalkLaplacian
        expect(cluster.matrixCandidate) == .combinationSigmoidWithTextErasure
        expect(cluster.noteMatrixCandidate) == .sigmoidOnEntities
        expect(cluster.numClustersCandidate) == .biggestDistanceInPercentages
        expect(cluster.weights[.navigation]) == 0.5
        expect(cluster.weights[.text]) == 0.9
        expect(cluster.weights[.entities]) == 0.4
    }

    /// Test adding and removing of data points from a (non-navigation) similarity matrix. For both addition and removal, test that all locations in the matrix (first, last, middle) work as expected
    func testAddandRemoveDataPointsToSimilarityMatrix() throws {
        let cluster = Cluster()
        // Checking the state of the matrix after initialization
        expect(cluster.textualSimilarityMatrix.matrix) == Matrix([0])
        try cluster.textualSimilarityMatrix.addDataPoint(similarities: [0], type: .page, numExistingNotes: 0, numExistingPages: 0)
        // Checking the first page doesn't influence the matrix
        expect(cluster.textualSimilarityMatrix.matrix) == Matrix([0])
        try cluster.textualSimilarityMatrix.addDataPoint(similarities: [0.5], type: .page, numExistingNotes: 0, numExistingPages: 1)
        // Checking the addition of the second page, first addition to the matrix
        expect(cluster.textualSimilarityMatrix.matrix.flat) == [0, 0.5, 0.5, 0]
        try cluster.textualSimilarityMatrix.addDataPoint(similarities: [0.3, 0.2], type: .page, numExistingNotes: 0, numExistingPages: 2)
        // Checking the addition of a third page, in position whereToAdd = .last
        expect(cluster.textualSimilarityMatrix.matrix.flat) == [0, 0.5, 0.3, 0.5, 0, 0.2, 0.3, 0.2, 0]
        try cluster.textualSimilarityMatrix.addDataPoint(similarities: [0.1, 0.1, 0.1], type: .note, numExistingNotes: 0, numExistingPages: 3)
        // Checking the addition of a first note, in position whereToAdd = .first
        expect(cluster.textualSimilarityMatrix.matrix.flat) == [0, 0.1, 0.1, 0.1, 0.1, 0, 0.5, 0.3, 0.1, 0.5, 0, 0.2, 0.1, 0.3, 0.2, 0]
        try cluster.textualSimilarityMatrix.addDataPoint(similarities: [0, 0.9, 0.9, 0.9], type: .note, numExistingNotes: 1, numExistingPages: 3)
        // Checking the addition of a second note, in position whereToAdd = .middle
        expect(cluster.textualSimilarityMatrix.matrix.flat) == [0, 0, 0.1, 0.1, 0.1, 0, 0, 0.9, 0.9, 0.9, 0.1, 0.9, 0, 0.5, 0.3, 0.1, 0.9, 0.5, 0, 0.2, 0.1, 0.9, 0.3, 0.2, 0]
        try cluster.textualSimilarityMatrix.removeDataPoint(index: 3)
        // Testing removal from the middle of the matrix
        expect(cluster.textualSimilarityMatrix.matrix.flat) == [0, 0, 0.1, 0.1, 0, 0, 0.9, 0.9, 0.1, 0.9, 0, 0.3, 0.1, 0.9, 0.3, 0]
        try cluster.textualSimilarityMatrix.removeDataPoint(index: 0)
        // Testing removal of index 0 (first position in the matrix)
        expect(cluster.textualSimilarityMatrix.matrix.flat) == [0, 0.9, 0.9, 0.9, 0, 0.3, 0.9, 0.3, 0]
        try cluster.textualSimilarityMatrix.removeDataPoint(index: 2)
        // Testing removal of the last position in the matrix
        expect(cluster.textualSimilarityMatrix.matrix.flat) == [0, 0.9, 0.9, 0]
    }

    /// Test removing of data points from the navigation matrix. When a data point is removed, that is connected to different other data points, connections between these data points are automatically created
    func testRemovalFromNavigationMatrix() throws {
        let cluster = Cluster()
        cluster.navigationMatrix.matrix = Matrix([[0, 1, 0], [1, 0, 1], [0, 1, 0]])
        try cluster.navigationMatrix.removeDataPoint(index: 1)
        expect(cluster.navigationMatrix.matrix.flat) == [0, 1, 1, 0]
    }

    /// Test the spectral clustering function on a small adjacency matrix
    func testSpectralClustering() throws {
        let cluster = Cluster()
        var i = 0
        var clustersResult = [Int]()
        cluster.adjacencyMatrix = Matrix([[0, 1, 0, 0, 0, 0, 0, 0, 1, 1],
                                          [1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                          [0, 0, 0, 1, 0, 0, 0, 0, 0, 0],
                                          [0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
                                          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                          [0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
                                          [0, 0, 0, 0, 0, 1, 0, 0, 0, 0],
                                          [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                          [1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                                          [1, 0, 0, 0, 0, 0, 0, 0, 0, 0]])
        repeat {
            let predictedClusters = try cluster.spectralClustering()
            clustersResult = cluster.stabilize(predictedClusters)
            i += 1
        } while clustersResult != [0, 0, 1, 1, 2, 3, 3, 4, 0, 0] && i < 1
        // For now it seems that resuls are very stable, if that changes the limit in the loop can be raised up to 10
        expect(clustersResult) == [0, 0, 1, 1, 2, 3, 3, 4, 0, 0]
    }

    /// Test the cosine similarity function
    func testCosineSimilarity() throws {
        let cluster = Cluster()
        let vec1 = [0.0, 1.5, 3.0, 4.5, 6.0]
        let vec2 = [2.0, 4.0, 6.0, 8.0, 10.0]
        let cossim = cluster.cosineSimilarity(vector1: vec1, vector2: vec2)

        expect(cossim).to(beCloseTo(0.9847319278346619, within: 0.0001))
    }

    /// Test that scoring of textual similarity between two texts is done correctly. At the same opportunity, test all similarity matrices (entities and navigation, in addition to text)
    func testScoreTextualEmbedding() throws {
        if #available(iOS 14, macOS 11, *) {
            let cluster = Cluster()
            var UUIDs: [UUID] = []
            for _ in 0...4 {
                UUIDs.append(UUID())
            }
            let pages = [
                Page(id: UUIDs[0], parentId: nil, title: nil, originalContent: ["Federer has played in an era where he dominated men's tennis together with Rafael Nadal and Novak Djokovic, who have been collectively referred to as the Big Three and are widely considered three of the greatest tennis players of all-time.[c] A Wimbledon junior champion in 1998, Federer won his first Grand Slam singles title at Wimbledon in 2003 at age 21. In 2004, he won three out of the four major singles titles and the ATP Finals,[d] a feat he repeated in 2006 and 2007. From 2005 to 2010, Federer made 18 out of 19 major singles finals. During this span, he won his fifth consecutive titles at both Wimbledon and the US Open. He completed the career Grand Slam at the 2009 French Open after three previous runner-ups to Nadal, his main rival up until 2010. At age 27, he also surpassed Pete Sampras's then-record of 14 Grand Slam men's singles titles at Wimbledon in 2009."]),
                Page(id: UUIDs[1], parentId: UUIDs[0], title: nil, originalContent: ["From childhood through most of his professional career, Nadal was coached by his uncle Toni. He was one of the most successful teenagers in ATP Tour history, reaching No. 2 in the world and winning 16 titles before his 20th birthday, including his first French Open and six Masters events. Nadal became No. 1 for the first time in 2008 after his first major victory off clay against his rival, the longtime top-ranked Federer, in a historic Wimbledon final. He also won an Olympic gold medal in singles that year in Beijing. After defeating Djokovic in the 2010 US Open final, the 24-year-old Nadal became the youngest man in the Open Era to achieve the career Grand Slam, and also became the first man to win three majors on three different surfaces (hard, grass and clay) the same calendar year. With his Olympic gold medal, he is also one of only two male players to complete the career Golden Slam."]),
                Page(id: UUIDs[2], parentId: nil, title: nil, originalContent: ["Sa victoire à Roland-Garros en 2009 lui a permis d'accomplir le Grand Chelem en carrière sur quatre surfaces différentes. En s'adjugeant ensuite l'Open d'Australie en 2010, il devient le premier joueur de l'histoire à avoir conquis l'ensemble de ses titres du Grand Chelem sur un total de cinq surfaces, depuis le remplacement du Rebound Ace australien par une nouvelle surface : le Plexicushion. Federer a réalisé le Petit Chelem de tennis à trois reprises, en 2004, 2006 et 2007, ce qui constitue à égalité avec Novak Djokovic, le record masculin toutes périodes confondues. Il est ainsi l'unique athlète à avoir gagné trois des quatre tournois du Grand Chelem deux années successives. Il atteint à trois reprises, et dans la même saison, les finales des quatre tournois majeurs, en 2006, 2007 et 2009, un fait unique dans l'histoire de ce sport."]),
                Page(id: UUIDs[3], parentId: UUIDs[2], title: nil, originalContent: ["Il est considéré par tous les spécialistes comme le meilleur joueur sur terre battue de l'histoire du tennis, établissant en effet des records majeurs, et par la plupart d'entre eux comme l'un des meilleurs joueurs de simple de tous les temps, si ce n’est le meilleur4,5,6,7. Il a remporté vingt tournois du Grand Chelem (un record qu'il détient avec Roger Federer et Novak Djokovic) et est le seul joueur à avoir remporté treize titres en simple dans un de ces quatre tournois majeurs : à Roland-Garros où il s'est imposé de 2005 à 2008, de 2010 à 2014, puis de 2017 à 2020. À l'issue de l'édition 2021, où il est détrôné en demi-finale par Novak Djokovic, il présente un bilan record de cent-cinq victoires pour trois défaites dans ce tournoi parisien, et ne compte aucune défaite en finale. Il a remporté également le tournoi de Wimbledon en 2008 et 2010, l'Open d'Australie 2009 et l'US Open 2010, 2013, 2017 et 2019. Il est ainsi le septième joueur de l'histoire du tennis à réaliser le « Grand Chelem en carrière » en simple. À ce titre, Rafael Nadal est le troisième joueur et le plus jeune à s'être imposé durant l'ère Open dans les quatre tournois majeurs sur quatre surfaces différentes, performance que seuls Roger Federer, Andre Agassi et Novak Djokovic ont accomplie."]),
                Page(id: UUIDs[4], parentId: nil, title:nil, originalContent: ["All"])
                ]
            let expectation = self.expectation(description: "Add page expectation")
            for page in pages.enumerated() {
                cluster.add(page: page.element, ranking: nil, completion: { result in
                    switch result {
                    case .failure(let error):
                        XCTFail(error.localizedDescription)
                    case .success(let result):
                        _ = result.0
                    }
                    if page.offset == pages.count - 1 {
                        expectation.fulfill()
                    }
                })
            }
            wait(for: [expectation], timeout: 1)
            expect(cluster.navigationMatrix.matrix.flat).to(beCloseTo([0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]))
            let embedders = (NLEmbedding.sentenceEmbedding(for: NLLanguage.english), NLEmbedding.sentenceEmbedding(for: NLLanguage.french))
            if embedders == (nil, nil) {
                expect(cluster.entitiesMatrix.matrix.flat).to(beCloseTo([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], within: 0.0001))
                expect(cluster.textualSimilarityMatrix.matrix.flat).to(beCloseTo([0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0], within: 0.0001))
            } else if embedders.1 == nil {
                expect(cluster.entitiesMatrix.matrix.flat).to(beCloseTo([0, 0.6, 0, 0, 0, 0.6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], within: 0.0001))
                expect(cluster.textualSimilarityMatrix.matrix.flat).to(beCloseTo([0, 0.9201, 1, 1, 0, 0.9201, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0], within: 0.0001))
            } else if embedders.0 == nil {
                expect(cluster.entitiesMatrix.matrix.flat).to(beCloseTo([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.8, 0, 0, 0, 0.8, 0, 0, 0, 0, 0, 0, 0], within: 0.0001))
                expect(cluster.textualSimilarityMatrix.matrix.flat).to(beCloseTo([0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0.9922, 1, 1, 1, 0.9922, 0, 1, 0, 0, 1, 1, 0], within: 0.0001))
            } else {
                expect(cluster.entitiesMatrix.matrix.flat).to(beCloseTo([0, 0.6, 0.6, 0.6667, 0, 0.6, 0, 0.4, 0.6, 0, 0.6, 0.4, 0, 0.8, 0, 0.6667, 0.6, 0.8, 0, 0, 0, 0, 0, 0, 0], within: 0.0001))
                expect(cluster.textualSimilarityMatrix.matrix.flat).to(beCloseTo([0, 0.9201, 1, 1, 0, 0.9201, 0, 1, 1, 0, 1, 1, 0, 0.9922, 1, 1, 1, 0.9922, 0, 1, 0, 0, 1, 1, 0], within: 0.0001))
            }
        }
    }

    /// Test that entities are detected correctly in a text
    func testFindingEntities() throws {
        let cluster = Cluster()
        let myText = "Roger Federer is the best tennis player to ever play the game, but Rafael Nadal is best on clay"
        let myEntities = cluster.findEntitiesInText(text: myText)
        expect(myEntities.entities["PlaceName"]) == []
        expect(myEntities.entities["OrganizationName"]) == []
        expect(myEntities.entities["PersonalName"]) == ["roger federer", "rafael nadal"]
    }

    /// Test that the Jaccard similarity measure between two sets of entities is computed correctly
    func testJaccardSimilarityMeasure() throws {
        let cluster = Cluster()
        let firstText = "Roger Federer is the best tennis player to ever play the game, but Rafael Nadal is best on clay"
        let secondText = "Rafael Nadal won Roland Garros 13 times"
        let firstTextEntities = cluster.findEntitiesInText(text: firstText)
        let secondTextEntities = cluster.findEntitiesInText(text: secondText)
        let similarity = cluster.jaccardEntities(entitiesText1: firstTextEntities, entitiesText2: secondTextEntities)
        expect(similarity).to(beCloseTo(0.5, within: 0.0001))
    }

    /// Test that titles are taken into account correctly for the sake of entity comparison
    func testEntitySimilarityOverTitles() throws {
        let cluster = Cluster()
        let expectation = self.expectation(description: "Add page expectation")
        var UUIDs: [UUID] = []
        for _ in 0...2 {
            UUIDs.append(UUID())
        }
        let pages = [
            Page(id: UUIDs[0], parentId: nil, title: "roger federer - Google search", cleanedContent: nil),
            Page(id: UUIDs[1], parentId: UUIDs[0], title: "Roger Federer", cleanedContent: nil),
            Page(id: UUIDs[2], parentId: UUIDs[0], title: "Pete Sampras", cleanedContent: nil)
            ]
        for page in pages.enumerated() {
            cluster.add(page: page.element, ranking: nil, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    _ = result.0
                }
                if page.offset == pages.count - 1 {
                    expectation.fulfill()
                }
            })
        }
        wait(for: [expectation], timeout: 1)

        let expectedEntitiesMatrix = [0.0, 1.0, 0.0,
                                      1.0, 0.0, 0.0,
                                      0.0, 0.0, 0.0]
        expect(cluster.entitiesMatrix.matrix.flat).to(beCloseTo(expectedEntitiesMatrix, within: 0.0001))
    }

    /// Test that the 'add' function sends back the sendRanking flag when the clustering process exceeds the time threshold
    func testRaiseRemoveFlag() throws {
        let cluster = Cluster()
        let expectation = self.expectation(description: "Raise remove flag")
        cluster.timeToRemove = 0.0
        var UUIDs: [UUID] = []
        for _ in 0...2 {
            UUIDs.append(UUID())
        }
        let pages = [
            Page(id: UUIDs[0], parentId: nil, title: nil, cleanedContent: "Roger Federer is the best tennis player to ever play the game, but Rafael Nadal is best on clay"),
            Page(id: UUIDs[1], parentId: UUIDs[0], title: nil, cleanedContent: "Tennis is a very fun game"),
            Page(id: UUIDs[2], parentId: UUIDs[0], title: nil, cleanedContent: "Pete Sampras and Roger Federer played 4 exhibition matches in 2008")
            ]
        for page in pages.enumerated() {
            cluster.add(page: page.element, ranking: nil, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    if page.offset == pages.count - 1 {
                        expect(result.flag) == .sendRanking
                    }
                }
                if page.offset == pages.count - 1 {
                    expectation.fulfill()
                }
            })
        }
        wait(for: [expectation], timeout: 1)
    }

    /// Test that when a ranking is sent along with  a request to 'add', the 3 least ranked pages are removed
    func testPageRemoval() throws {
        let cluster = Cluster()
        cluster.noteContentThreshold = 3
        // Here we don't want to test that notes with little content are not added
        let expectation = self.expectation(description: "Add page expectation")
        var UUIDs: [UUID] = []
        for _ in 0...6 {
            UUIDs.append(UUID())
        }
        let pages = [
            Page(id: UUIDs[0], parentId: nil, title: "man", cleanedContent: "A man is eating food."),
            Page(id: UUIDs[1], parentId: UUIDs[0], title: "girl", cleanedContent: "The girl is carrying a baby."),
            Page(id: UUIDs[2], parentId: UUIDs[0], title: "man", cleanedContent: "A man is eating food."),
            Page(id: UUIDs[3], parentId: UUIDs[0], title: "girl", cleanedContent: "The girl is carrying a baby."),
            Page(id: UUIDs[4], parentId: UUIDs[0], title: "girl", cleanedContent: "The girl is carrying a baby."),
            Page(id: UUIDs[5], parentId: UUIDs[0], title: "man", cleanedContent: "A man is eating food."),
            Page(id: UUIDs[6], parentId: UUIDs[0], title: "fille", cleanedContent: "La fille est en train de porter un bébé.")
            ]
        for page in pages.enumerated() {
            var ranking: [UUID]?
            if page.offset == pages.count - 1 {
                ranking = [UUIDs[1], UUIDs[4], UUIDs[2], UUIDs[3], UUIDs[5], UUIDs[0]]
            }
            cluster.add(page: page.element, ranking: ranking, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    _ = result
                }
                if page.offset == pages.count - 1 {
                    expectation.fulfill()
                }
            })
            if page.offset == 4 {
                let myUUID = UUID()
                let myNote = ClusteringNote(id: myUUID, title: "Roger Federer", content: "Roger Federer is the best Tennis player in history")
                cluster.add(note: myNote, ranking: nil, completion: { result in
                    switch result {
                    case .failure(let error):
                        XCTFail(error.localizedDescription)
                    case .success(let result):
                        _ = result
                    }
                })
            }
        }
        wait(for: [expectation], timeout: 1)
        var attachedPages = [UUID]()
        for page in cluster.pages {
            attachedPages += page.attachedPages
        }
        expect(Set(attachedPages)) == Set([]) //Set([1, 4, 2])
        expect(cluster.adjacencyMatrix.rows) == 5 // 4 pages and one note
        expect(cluster.pages.count) == 4
        expect(cluster.notes.count) == 1
    }

    /// A page that was removed from the matrices is visited again by the user. Test that it is readded correctly and removed from attachedPages
    func testRevisitPageAfterRemoval() throws {
        let cluster = Cluster()
        let firstExpectation = self.expectation(description: "Add page expectation")
        let secondExpectation = self.expectation(description: "Add page expectation")
        var UUIDs: [UUID] = []
        for _ in 0...4 {
            UUIDs.append(UUID())
        }
        let firstPages = [
            Page(id: UUIDs[0], parentId: nil, title: "Page 1", cleanedContent: "A man is eating food."),
            Page(id: UUIDs[1], parentId: UUIDs[0], title: "Page 2", cleanedContent: "The girl is carrying a baby."),
            Page(id: UUIDs[2], parentId: UUIDs[0], title: "Page 3", cleanedContent: "A man is eating food.")
            ]
        let secondPages = [
            Page(id: UUIDs[3], parentId: UUIDs[0], title: "Page 4", cleanedContent: "The girl is carrying a baby."),
            Page(id: UUIDs[4], parentId: UUIDs[0], title: "Page 5", cleanedContent: "The girl is carrying a baby.")
            ]
        for page in firstPages.enumerated() {
            cluster.add(page: page.element, ranking: nil, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    _ = result.0
                }
                if page.offset == firstPages.count - 1 {
                    firstExpectation.fulfill()
                }
            })
        }
        wait(for: [firstExpectation], timeout: 1)
        cluster.pages[0].attachedPages = [UUIDs[3]]
        cluster.pages[1].attachedPages = [UUIDs[4]]
        for page in secondPages.enumerated() {
            cluster.add(page: page.element, ranking: nil, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    _ = result.0
                }
                if page.offset == secondPages.count - 1 {
                    secondExpectation.fulfill()
                }
            })
        }
        wait(for: [secondExpectation], timeout: 1)
        expect(cluster.pages[0].attachedPages) == []
        expect(cluster.pages[1].attachedPages) == []
    }

    /// When removing a page from the matrix, chage that if the most similar data point to that page is a note, that does not create a problem
    func testRemovingPageWithSimilarNote() throws {
        let cluster = Cluster()
        cluster.noteContentThreshold = 3
        // Here we don't want to test that notes with little content are not added
        let expectation = self.expectation(description: "Add note expectation")
        var UUIDs: [UUID] = []
        for i in 0...5 {
            UUIDs.append(UUID())
            let myPage = Page(id: UUIDs[i], parentId: nil, title: nil, cleanedContent: "Here's some text for you")
            // The pages themselves don't matter as we will later force the similarity matrix
            cluster.add(page: myPage, ranking: nil, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    _ = result.0
                }
            })
        }
        for i in 0...2 {
            let myNote = ClusteringNote(id: UUID(), title: "My note", content: "This is my note")
            cluster.add(note: myNote, ranking: nil, completion: { result in
                switch result {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .success(let result):
                    _ = result.0
                }
                if i == 2 {
                    expectation.fulfill()
                }
            })
        }
        wait(for: [expectation], timeout: 1)
        cluster.adjacencyMatrix = Matrix([[0, 0, 0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4],
                                   [0, 0, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6],
                                   [0, 0, 0, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
                                   [0.9, 0.1, 0.3, 0, 0.5, 0.5, 0.5, 0.5, 0.5],
                                   [0.8, 0.2, 0.3, 0.5, 0, 0.7, 0.2, 0.1, 0.1],
                                   [0.7, 0.3, 0.3, 0.5, 0.7, 0, 0.6, 0.2, 0.1],
                                   [0.6, 0.4, 0.3, 0.5, 0.2, 0.6, 0, 0.9, 0.3],
                                   [0.5, 0.5, 0.3, 0.5, 0.1, 0.2, 0.9, 0, 0.4],
                                   [0.4, 0.6, 0.3, 0.5, 0.1, 0.1, 0.3, 0.4, 0]])
        try cluster.remove(ranking: [UUIDs[0]])
        expect(cluster.pages[0].id) == UUIDs[1]
        expect(cluster.pages[0].attachedPages) == [] // [0]
    }

    /// Trying to add a note with little content should throw an expected error and not add the note
    func testNoteWithLittleContentIsNotAdded() throws {
        let cluster = Cluster()
        let firstShortNote = ClusteringNote(id: UUID(), title: "First short note", content: "This is a short note")
        let longNote = ClusteringNote(id: UUID(), title: "Roger Federer", content: "Roger Federer (German: [ˈrɔdʒər ˈfeːdərər]; born 8 August 1981) is a Swiss professional tennis player. He is ranked No. 9 in the world by the Association of Tennis Professionals (ATP). He has won 20 Grand Slam men's singles titles, an all-time record shared with Rafael Nadal and Novak Djokovic. Federer has been world No. 1 in the ATP rankings a total of 310 weeks – including a record 237 consecutive weeks – and has finished as the year-end No. 1 five times. Federer has won 103 ATP singles titles, the second most of all-time behind Jimmy Connors, including a record six ATP Finals. Federer has played in an era where he dominated men's tennis together with Rafael Nadal and Novak Djokovic, who have been collectively referred to as the Big Three and are widely considered three of the greatest tennis players of all-time.[c] A Wimbledon junior champion in 1998, Federer won his first Grand Slam singles title at Wimbledon in 2003 at age 21. In 2004, he won three out of the four major singles titles and the ATP Finals,[d] a feat he repeated in 2006 and 2007. From 2005 to 2010, Federer made 18 out of 19 major singles finals. During this span, he won his fifth consecutive titles at both Wimbledon and the US Open. He completed the career Grand Slam at the 2009 French Open after three previous runner-ups to Nadal, his main rival up until 2010. At age 27, he also surpassed Pete Sampras's then-record of 14 Grand Slam men's singles titles at Wimbledon in 2009.")
        let secondShortNote = ClusteringNote(id: UUID(), title: "Second short note", content: "This is a short note")
        let myNotes = [firstShortNote, longNote, secondShortNote]
        let expectation = self.expectation(description: "Add note expectation")
        for aNote in myNotes.enumerated() {
            cluster.add(note: aNote.element, ranking: nil, completion: { result in
                switch result {
                case .failure(let error):
                    if error as! Cluster.AdditionError != Cluster.AdditionError.notEnoughTextInNote {
                        XCTFail(error.localizedDescription)
                    }
                case .success(let result):
                    _ = result.0
                }
                if aNote.offset == myNotes.count - 1 {
                    expectation.fulfill()
                }
            })
        }
        wait(for: [expectation], timeout: 1)
        expect(cluster.notes.count) == 1
        expect(cluster.notes[0].id) == longNote.id
    }
    
    func testCreateSimilarities() throws {
        let cluster = Cluster()
        cluster.textualSimilarityMatrix.matrix = Matrix([[0, 0, 0, 0.9, 0.8, 0.7],
                                                         [0, 0, 0, 0.5, 0.5, 0.5],
                                                         [0, 0, 0, 0.1, 0.2, 0.3],
                                                         [0.9, 0.5, 0.1, 0, 0.5, 0.2],
                                                         [0.8, 0.5, 0.2, 0.5, 0, 0.3],
                                                         [0.7, 0.5, 0.3, 0.2, 0.3, 0]])
        cluster.entitiesMatrix.matrix = Matrix([[0, 0, 0, 0.4, 0.3, 0.2],
                                                [0, 0, 0, 0.5, 0.5, 0.5],
                                                [0, 0, 0, 0.1, 0.2, 0.3],
                                                [0.4, 0.5, 0.1, 0, 0.5, 0.2],
                                                [0.3, 0.5, 0.2, 0.5, 0, 0.3],
                                                [0.2, 0.5, 0.3, 0.2, 0.3, 0]])
        cluster.notes = [ClusteringNote(id: UUID(), title: "First note", content: "note"),
                         ClusteringNote(id: UUID(), title: "Second note", content: "note"),
                         ClusteringNote(id: UUID(), title: "Third note", content: "note")]
        cluster.pages = [Page(id: UUID(), parentId: nil, title: "First page", cleanedContent: "page"),
                         Page(id: UUID(), parentId: nil, title: "Second page", cleanedContent: "page"),
                         Page(id: UUID(), parentId: nil, title: "Third page", cleanedContent: "page")]
        let activeSources = [cluster.pages[0].id]
        let noteGroups = [[cluster.notes[0].id], [cluster.notes[1].id], [cluster.notes[2].id], [], []]
        let pageGroups = [[], [cluster.pages[2].id], [], [cluster.pages[0].id, cluster.pages[1].id]]
        
        let mySimilarities = cluster.createSimilarities(pageGroups: pageGroups, noteGroups: noteGroups, activeSources: activeSources)
        expect(mySimilarities[cluster.notes[0].id]) == [:]
        expect(mySimilarities[cluster.notes[1].id]) == [cluster.pages[2].id: 0.5625]
        expect(mySimilarities[cluster.notes[2].id]) == [:]
        expect(mySimilarities[cluster.pages[0].id]) == [cluster.pages[1].id: 0.5625]
    }
    // swiftlint:disable:next file_length
}
