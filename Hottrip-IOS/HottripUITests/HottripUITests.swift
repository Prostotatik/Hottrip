import XCTest

/// Сценарии для съёмки интеракций на симуляторе (видео пишет scripts/sim-shots.sh --ui <сценарий>).
/// Паузы между шагами — чтобы на видео успели доиграть анимации. Экран открывается launch-аргументами
/// демо-запуска (DemoLaunch.swift), поэтому каждый сценарий начинается сразу с нужного места.
final class HottripUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Сценарии

    /// Главная: вход hero (P0-1) → «Горящие предложения» (нажатие P0-3) → выдача → Lara Sands зумом из карточки
    /// (P0-4) → листание галереи → назад свайпом (зум обратно) → назад на главную (вход hero не повторяется).
    func testHomeToTour() {
        let app = launch("home")
        pause(2.0)
        tap(app.buttons["home.hot"])
        pause(1.5)
        let card = app.buttons["tourCard.t1"]
        scrollTo(card, in: app)
        tap(card)
        pause(1.5)
        // Свайп именно по фото галереи: `app.swipeLeft()` попадал в «Входит в стоимость».
        let dots = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'Фото '")).firstMatch
        swipeGallery(app, left: true)
        pause(1.2)
        swipeGallery(app, left: true)
        pause(1.5)
        XCTAssertEqual(dots.label, "Фото 3 из 4")
        swipeBack(app)
        XCTAssertTrue(app.buttons["tourCard.t1"].waitForExistence(timeout: 3))
        pause(1.2)
        swipeBack(app)
        XCTAssertTrue(app.buttons["home.hot"].waitForExistence(timeout: 3))
        pause(1.5)
    }

    /// Галерея тура (P0-5): два свайпа влево и один вправо — точка-капсула перетекает, фото отстаёт от края.
    func testGallerySwipe() {
        let app = launch("tour")
        pause(1.5)
        let dots = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'Фото '")).firstMatch
        XCTAssertEqual(dots.label, "Фото 1 из 4")
        swipeGallery(app, left: true)
        pause(1.0)
        swipeGallery(app, left: true)
        pause(1.0)
        XCTAssertEqual(dots.label, "Фото 3 из 4")
        swipeGallery(app, left: false)
        pause(1.2)
        XCTAssertEqual(dots.label, "Фото 2 из 4")
    }

    /// Тур: раскрытие «Проживание» (P1-9) → прокрутка к операторам (P0-6): рамка переезжает, строки не сдвигаются,
    /// цена в шапке катится (если шапка за экраном — над CTA на 1,5 с плашка с ценой оператора).
    func testOperatorSwitch() {
        let app = launch("tour")
        pause(1.5)
        tap(app.buttons["tour.included.hotel"])
        pause(1.5)
        // Шапка с ценой уезжает за верх экрана: смена оператора подтверждается плашкой над CTA.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        pause(1.0)
        let coral = app.buttons["tour.operator.coral"]
        scrollTo(coral, in: app, bottomInset: 0.25)
        pause(1.5)
        let before = coral.frame
        tap(coral)
        // Цена Coral видна и в списке, и в шапке (или, если шапка ушла за экран, в плашке над CTA).
        let coralPrice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '890'"))
        XCTAssertGreaterThanOrEqual(coralPrice.count, 2, "цена выбранного оператора не показана вне списка")
        pause(0.5)
        XCTAssertEqual(coral.frame.minY, before.minY, accuracy: 1, "список операторов сдвинулся при выборе")
        pause(1.5)
        tap(app.buttons["tour.operator.pegas"])
        pause(2.0)
        tap(app.buttons["tour.operator.anex"])
        pause(2.0)
    }

    /// Лайк в выдаче: сердце + тост «Следим за ценой», тост сам уходит; повторный тап — снять лайк.
    func testLikeResults() {
        let app = launch("results")
        pause(1.5)
        tap(app.buttons["tourCard.favorite.t1"])
        let toast = app.staticTexts["Следим за ценой. Сообщим, если станет дешевле"]
        XCTAssertTrue(toast.waitForExistence(timeout: 3))
        XCTAssertTrue(toast.waitForNonExistence(timeout: 6), "тост не ушёл сам")
        pause(1.0)
        tap(app.buttons["tourCard.favorite.t1"])
        pause(1.5)
    }

    /// Лайк на карточке тура.
    func testLikeTour() {
        let app = launch("tour")
        pause(1.5)
        tap(app.buttons["tour.favorite"])
        let toast = app.staticTexts["Следим за ценой. Сообщим, если станет дешевле"]
        XCTAssertTrue(toast.waitForExistence(timeout: 3))
        XCTAssertTrue(toast.waitForNonExistence(timeout: 6), "тост не ушёл сам")
        pause(1.0)
    }

    /// Способы оплаты (P0-7): Payme → Click → рассрочка (график раскрывается, CTA «…/мес») → 6 месяцев.
    func testPaymentMethods() {
        let app = launch("payment")
        pause(1.5)
        tap(app.buttons["payment.method.click"])
        pause(1.2)
        let payme = app.buttons["payment.method.payme"]
        XCTAssertFalse(payme.isSelected)
        tap(app.buttons["payment.method.installment"])
        pause(1.5)
        let pay = app.buttons["payment.pay"]
        XCTAssertTrue(pay.label.hasSuffix("/мес"), pay.label)
        XCTAssertTrue(pay.isHittable)
        tap(app.buttons["6 мес"])
        pause(1.5)
        XCTAssertTrue(pay.label.contains("580"), pay.label)
        pause(1.0)
    }

    /// Оплата Payme: «Оплачиваем…» → галочка в CTA → бронь проявляется поверх оплаты (P1-11).
    func testPaymentSuccess() {
        let app = launch("payment")
        pause(1.5)
        tap(app.buttons["payment.pay"])
        XCTAssertTrue(app.staticTexts["Бронь подтверждена"].waitForExistence(timeout: 10))
        pause(3.0)
    }

    /// Оплата картой: раскрытие формы карты, ввод с клавиатуры, отказ банка на тестовой карте.
    func testPaymentCardFailure() {
        let app = launch("payment")
        pause(1.2)
        tap(app.buttons["payment.method.card"])
        pause(1.5)
        let number = app.textFields["field.Номер карты"]
        tap(number)
        pause(1.0)
        number.typeText("8600493012345678")
        pause(1.0)
        // Фокус сам перешёл в «Срок» после 16 цифр; повторный тап по полю в фокусе открыл бы меню автозаполнения.
        let expiry = app.textFields["field.Срок"]
        XCTAssertTrue(expiry.waitForExistence(timeout: 2))
        // Поле над клавиатурой (если симулятор её показывает: при вводе с XCUITest она иногда прячется).
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists { XCTAssertLessThan(expiry.frame.maxY, keyboard.frame.minY) }
        expiry.typeText("0828")
        pause(1.5)
        tap(app.buttons["payment.pay"])
        let declined = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Банк отклонил платёж'")).firstMatch
        XCTAssertTrue(declined.waitForExistence(timeout: 10), "нет баннера отказа банка")
        pause(2.5)
    }

    /// Опечатка в номере карты: после 16 цифр поле краснеет и пишет «Проверьте номер карты» ещё до
    /// «Оплатить»; исправили последнюю цифру — ошибка уходит, фокус сам переходит в «Срок».
    func testPaymentCardInvalid() {
        let app = launch("payment")
        pause(1.2)
        tap(app.buttons["payment.method.card"])
        pause(1.2)
        let number = app.textFields["field.Номер карты"]
        tap(number)
        number.typeText("8600123456789011")
        let error = app.staticTexts["Проверьте номер карты"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        pause(2.0)
        number.typeText(XCUIKeyboardKey.delete.rawValue + "2")
        XCTAssertTrue(error.waitForNonExistence(timeout: 3))
        pause(1.0)
        app.textFields["field.Срок"].typeText("0828")
        pause(2.0)
        XCTAssertTrue(app.buttons["payment.pay"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["payment.pay"].isEnabled)
        pause(1.0)
    }

    /// Поиск: sheet «Даты» (день, туристы, живой счётчик CTA), sheet «Бюджет» (слайдер), назад на главную
    /// и вкладки Избранное → Профиль → Главная (подложка таб-бара переезжает, P1-10).
    func testSearchPickers() {
        let app = launch("search")
        pause(1.2)
        tap(app.buttons["search.field.Даты"])
        pause(1.2)
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Сб' AND label CONTAINS 'окт'")).firstMatch)
        pause(1.0)
        tap(app.buttons["travelers.plus"])
        pause(1.0)
        let datesTitle = app.staticTexts["Даты"]
        datesTitle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(datesTitle.waitForNonExistence(timeout: 3))
        pause(1.0)
        tap(app.buttons["search.field.Бюджет"])
        pause(1.0)
        let budget = app.descendants(matching: .any)["Бюджет"].firstMatch
        budget.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: budget.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        pause(0.8)
        tap(app.buttons["budget.done"])
        XCTAssertTrue(app.buttons["budget.done"].waitForNonExistence(timeout: 3))
        pause(1.0)
        tap(app.buttons["nav.back"])
        pause(1.2)
        for tab in ["favorites", "profile", "home"] {
            tap(app.buttons["tab.\(tab)"])
            pause(1.2)
        }
    }

    /// Популярные направления (P1-8): «Куда» пусто — «Найти туры» неактивна; тап по ОАЭ подставляет
    /// направление в поле с подсветкой, без перехода; «Найти туры» ведёт в выдачу Дубая.
    func testSearchPopular() {
        let app = launch("search", state: "empty")
        pause(1.5)
        let find = app.buttons["search.find"]
        XCTAssertFalse(find.isEnabled)
        tap(app.buttons["search.popular.uae"])
        pause(0.3)
        XCTAssertTrue(app.buttons["search.field.Куда"].label.contains("ОАЭ"), app.buttons["search.field.Куда"].label)
        pause(1.5)
        tap(app.buttons["search.popular.egypt"])
        pause(1.5)
        XCTAssertTrue(find.isEnabled)
        tap(find)
        XCTAssertTrue(app.staticTexts["Шарм-эш-Шейх"].waitForExistence(timeout: 3))
        pause(1.5)
    }

    // MARK: Помощники

    private func launch(_ screen: String, state: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-demoScreen", screen] + (state.map { ["-demoState", $0] } ?? [])
        app.launch()
        return app
    }

    /// Тап только по видимому и доступному элементу: иначе XCUITest «тапает» в {-1, -1} и сценарий ложно зелёный.
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "нет элемента \(element)", file: file, line: line)
        XCTAssertTrue(element.isHittable, "элемент перекрыт: \(element)", file: file, line: line)
        element.tap()
    }

    /// Листает вверх, пока элемент не окажется в видимой части экрана над нижним баром.
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, bottomInset: CGFloat = 0.2) {
        let limit = app.frame.height * (1 - bottomInset)
        for _ in 0..<10 {
            if element.exists, element.isHittable, element.frame.maxY < limit, element.frame.minY > 100 { return }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            pause(0.4)
        }
    }

    /// Свайп по фото галереи тура (верхние 400 pt экрана).
    private func swipeGallery(_ app: XCUIApplication, left: Bool) {
        let (from, to): (CGFloat, CGFloat) = left ? (0.85, 0.15) : (0.15, 0.85)
        app.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.18))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.18)))
    }

    /// Свайп «назад» от левого края.
    private func swipeBack(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "pause")], timeout: seconds)
    }
}
